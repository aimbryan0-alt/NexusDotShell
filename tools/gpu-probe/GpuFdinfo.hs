{-# LANGUAGE ScopedTypeVariables #-}

module Main (main) where

import Control.Exception (IOException, try)
import Control.Monad (foldM)
import qualified Data.ByteString.Char8 as ByteString
import Data.Char (isDigit, isSpace)
import Data.List (foldl', isPrefixOf)
import qualified Data.Map.Strict as Map
import System.Directory (listDirectory)
import System.Environment (getArgs)
import System.Exit (die)
import System.FilePath ((</>))
import Text.Read (readMaybe)

type Key = (Int, String, String, String)
type Stats = (Integer, Integer, Integer)
type Records = Map.Map Key Stats

data Partial = Partial
  { driver :: String
  , pci :: String
  , client :: String
  , engine :: Integer
  , sharedKB :: Integer
  , localKB :: Integer
  }

emptyPartial :: Partial
emptyPartial = Partial "" "" "" 0 0 0

trim :: String -> String
trim = dropWhile isSpace . reverse . dropWhile isSpace . reverse

number :: String -> Maybe Integer
number value =
  let token = takeWhile (not . isSpace) (trim value)
   in if not (null token) && all isDigit token then readMaybe token else Nothing

memoryKB :: String -> Integer
memoryKB value =
  case words (trim value) of
    [] -> 0
    amount : unit ->
      case readMaybe amount of
        Nothing -> 0
        Just n ->
          case unit of
            "MiB" : _ -> n * 1024
            "GiB" : _ -> n * 1048576
            _ -> n

updateLine :: Partial -> String -> Partial
updateLine partial line =
  case break (== ':') line of
    (_, []) -> partial
    (rawKey, _ : rawValue) ->
      let key = trim rawKey
          value = trim rawValue
       in case key of
            "drm-driver" -> partial {driver = value}
            "drm-pdev" -> partial {pci = value}
            "drm-client-id" -> partial {client = value}
            _ | "drm-engine-" `isPrefixOf` key ->
                  partial {engine = engine partial + maybe 0 id (number value)}
              | "drm-total-system" `isPrefixOf` key ->
                  partial {sharedKB = sharedKB partial + memoryKB value}
              | "drm-total-vram" `isPrefixOf` key
                  || "drm-total-local" `isPrefixOf` key ->
                  partial {localKB = localKB partial + memoryKB value}
              | otherwise -> partial

parseRecord :: Int -> String -> String -> Maybe (Key, Stats)
parseRecord pid fd contents =
  let result = foldl' updateLine emptyPartial (lines contents)
      identifier = if null (client result) then fd else client result
      stats = (engine result, sharedKB result, localKB result)
   in if null (driver result) || null (pci result) || stats == (0, 0, 0)
        then Nothing
        else Just ((pid, pci result, driver result, identifier), stats)

mergeStats :: Stats -> Stats -> Stats
mergeStats (engineA, sharedA, localA) (engineB, sharedB, localB) =
  (max engineA engineB, max sharedA sharedB, max localA localB)

readDirectory :: FilePath -> IO [FilePath]
readDirectory path = do
  result <- try (listDirectory path) :: IO (Either IOException [FilePath])
  pure (either (const []) id result)

readFdinfo :: FilePath -> IO (Maybe String)
readFdinfo path = do
  result <- try (ByteString.readFile path) :: IO (Either IOException ByteString.ByteString)
  pure (either (const Nothing) (Just . ByteString.unpack) result)

pidFromName :: String -> Maybe Int
pidFromName name
  | null name || not (all isDigit name) = Nothing
  | otherwise = readMaybe name

scanRoot :: FilePath -> IO Records
scanRoot root = do
  pids <- readDirectory root
  foldM scanPid Map.empty [(name, pid) | name <- pids, Just pid <- [pidFromName name]]
  where
    scanPid records (pidName, pid) = do
      let directory = root </> pidName </> "fdinfo"
      fds <- readDirectory directory
      foldM (scanFd pid directory) records [fd | fd <- fds, pidFromName fd /= Nothing]

    scanFd pid directory records fd = do
      contents <- readFdinfo (directory </> fd)
      case contents >>= parseRecord pid fd of
        Nothing -> pure records
        Just (key, stats) ->
          pure (Map.insertWith mergeStats key stats records)

emitRecords :: Records -> IO ()
emitRecords records =
  mapM_ emit (Map.toAscList records)
  where
    emit ((pid, pciAddress, driverName, clientId), (engineNs, shared, local)) =
      putStrLn
        ( "ENGINE|" ++ show pid ++ "|" ++ pciAddress ++ "|" ++ driverName ++ "|"
            ++ clientId ++ "|" ++ show engineNs ++ "|" ++ show shared ++ "|"
            ++ show local
        )

positiveCount :: String -> Maybe Int
positiveCount value = do
  parsed <- readMaybe value
  if parsed > 0 && parsed <= 1000000 then Just parsed else Nothing

parseArgs :: [String] -> Either String (FilePath, Maybe Int)
parseArgs = go "/proc" Nothing
  where
    go root iterations [] = Right (root, iterations)
    go _ iterations ("--proc-root" : path : rest) = go path iterations rest
    go root _ ("--benchmark" : count : rest) =
      maybe (Left "invalid benchmark iteration count") (\n -> go root (Just n) rest)
        (positiveCount count)
    go _ _ _ = Left "usage: gpu-fdinfo [--proc-root PATH] [--benchmark ITERATIONS]"

runBenchmark :: FilePath -> Int -> IO ()
runBenchmark root count = do
  total <- go count 0
  putStrLn ("samples=" ++ show count ++ " records=" ++ show total)
  where
    go 0 total = pure total
    go remaining total = do
      records <- scanRoot root
      go (remaining - 1) (total + Map.size records)

main :: IO ()
main = do
  arguments <- getArgs
  case parseArgs arguments of
    Left message -> die message
    Right (root, Just count) -> runBenchmark root count
    Right (root, Nothing) -> scanRoot root >>= emitRecords
