#define NOB_IMPLEMENTATION
#include "nob.h"

#include <errno.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#define GPU_BUILD_DIR "tools/gpu-probe/build"
#define GPU_C_BINARY GPU_BUILD_DIR "/gpu-fdinfo-c"
#define GPU_HASKELL_BINARY GPU_BUILD_DIR "/gpu-fdinfo-haskell"
#define SYSTEM_STATS_BUILD_DIR "tools/system-stats/build"
#define SYSTEM_STATS_BINARY SYSTEM_STATS_BUILD_DIR "/system-stats-c"

static bool ensure_directories(const char *path) {
  char *copy = strdup(path);
  if (copy == NULL) {
    nob_log(NOB_ERROR, "out of memory");
    return false;
  }

  bool ok = true;
  for (char *p = copy + (copy[0] == '/'); *p != '\0'; p++) {
    if (*p != '/')
      continue;
    *p = '\0';
    if (copy[0] != '\0' && !nob_mkdir_if_not_exists(copy)) {
      ok = false;
      break;
    }
    *p = '/';
  }
  if (ok && !nob_mkdir_if_not_exists(copy))
    ok = false;
  free(copy);
  return ok;
}

static bool command_in_path(const char *command) {
  if (strchr(command, '/') != NULL)
    return access(command, X_OK) == 0;
  const char *path = getenv("PATH");
  if (path == NULL)
    return false;

  char *copy = strdup(path);
  if (copy == NULL)
    return false;
  bool found = false;
  char *save = NULL;
  for (char *directory = strtok_r(copy, ":", &save);
       directory != NULL;
       directory = strtok_r(NULL, ":", &save)) {
    const char *prefix = directory[0] == '\0' ? "." : directory;
    char candidate[PATH_MAX];
    int length = snprintf(candidate, sizeof(candidate), "%s/%s", prefix, command);
    if (length >= 0 && (size_t)length < sizeof(candidate)
        && access(candidate, X_OK) == 0) {
      found = true;
      break;
    }
  }
  free(copy);
  return found;
}

static bool build_c_collector(void) {
  const char *output = GPU_C_BINARY;
  const char *inputs[] = {"tools/gpu-probe/gpu_fdinfo.c", "nob.c", "nob.h"};
  int rebuild = nob_needs_rebuild(output, inputs, sizeof(inputs) / sizeof(inputs[0]));
  if (rebuild < 0)
    return false;
  if (rebuild == 0)
    return true;

  const char *compiler = getenv("CC");
  if (compiler == NULL || compiler[0] == '\0')
    compiler = "cc";
  Nob_Cmd command = {0};
  nob_cmd_append(&command, compiler, "-std=c11", "-O2", "-Wall", "-Wextra",
      "-Werror", "-o", output, "tools/gpu-probe/gpu_fdinfo.c");
  return nob_cmd_run(&command);
}

static bool build_system_stats_collector(void) {
  const char *output = SYSTEM_STATS_BINARY;
  const char *inputs[] = {"tools/system-stats/system_stats.c", "nob.c", "nob.h"};
  int rebuild = nob_needs_rebuild(output, inputs, sizeof(inputs) / sizeof(inputs[0]));
  if (rebuild < 0)
    return false;
  if (rebuild == 0)
    return true;

  const char *compiler = getenv("CC");
  if (compiler == NULL || compiler[0] == '\0')
    compiler = "cc";
  Nob_Cmd command = {0};
  nob_cmd_append(&command, compiler, "-std=c11", "-O2", "-Wall", "-Wextra",
      "-Werror", "-o", output, "tools/system-stats/system_stats.c");
  return nob_cmd_run(&command);
}

static bool build_haskell_collector(void) {
  if (!command_in_path("ghc")) {
    nob_log(NOB_INFO, "GHC unavailable; skipping optional Haskell fallback");
    return true;
  }

  const char *output = GPU_HASKELL_BINARY;
  const char *inputs[] = {"tools/gpu-probe/GpuFdinfo.hs", "nob.c", "nob.h"};
  int rebuild = nob_needs_rebuild(output, inputs, sizeof(inputs) / sizeof(inputs[0]));
  if (rebuild < 0)
    return false;
  if (rebuild == 0)
    return true;
  if (!ensure_directories(GPU_BUILD_DIR "/ghc"))
    return false;

  Nob_Cmd command = {0};
  nob_cmd_append(&command, "ghc", "-O2", "-Wall", "-Werror",
      "-outputdir", GPU_BUILD_DIR "/ghc",
      "-o", output, "tools/gpu-probe/GpuFdinfo.hs");
  return nob_cmd_run(&command);
}

static bool build_helpers(void) {
  return ensure_directories(GPU_BUILD_DIR)
      && build_c_collector()
      && ensure_directories(SYSTEM_STATS_BUILD_DIR)
      && build_system_stats_collector()
      && build_haskell_collector();
}

static bool install_desktop_entry(void) {
  const char *data_home = getenv("XDG_DATA_HOME");
  if (data_home == NULL || data_home[0] == '\0') {
    const char *home = getenv("HOME");
    if (home == NULL || home[0] == '\0') {
      nob_log(NOB_ERROR, "neither XDG_DATA_HOME nor HOME is set");
      return false;
    }
    data_home = nob_temp_sprintf("%s/.local/share", home);
  }

  const char *applications = nob_temp_sprintf("%s/applications", data_home);
  const char *desktop_path = nob_temp_sprintf("%s/com.nexusdotshell.shell.desktop", applications);
  if (!ensure_directories(applications))
    return false;

  const char *cwd = nob_get_current_dir_temp();
  const char *contents = nob_temp_sprintf(
      "[Desktop Entry]\n"
      "Version=1.0\n"
      "Type=Application\n"
      "Name=NexusDotShell\n"
      "Comment=Wayland desktop shell\n"
      "Exec=quickshell -p \"%s\"\n"
      "Path=%s\n"
      "Terminal=false\n"
      "NoDisplay=true\n"
      "DBusActivatable=false\n",
      cwd, cwd);
  return nob_write_entire_file(desktop_path, contents, strlen(contents));
}

static bool run_shell(bool detached) {
  if (!build_helpers() || !install_desktop_entry())
    return false;

  const char *quickshell = getenv("QS");
  if (quickshell == NULL || quickshell[0] == '\0')
    quickshell = "quickshell";
  Nob_Cmd command = {0};
  if (detached)
    nob_cmd_append(&command, quickshell, "-p", ".", "-d");
  else
    nob_cmd_append(&command, quickshell, "-p", ".");
  return nob_cmd_run(&command);
}

static bool stop_shell(void) {
  if (!ensure_directories("build"))
    return false;
  const char *instances_path = "build/quickshell-instances.json";
  Nob_Cmd list = {0};
  nob_cmd_append(&list, "qs", "list", "--json", "--path", ".");
  if (!nob_cmd_run(&list, .stdout_path = instances_path))
    return false;

  FILE *file = fopen(instances_path, "r");
  if (file == NULL) {
    nob_log(NOB_ERROR, "could not read %s: %s", instances_path, strerror(errno));
    return false;
  }
  char line[512];
  bool ok = true;
  size_t stopped = 0;
  while (fgets(line, sizeof(line), file) != NULL) {
    for (char *pid_field = line;
         (pid_field = strstr(pid_field, "\"pid\"")) != NULL;
         pid_field += 5) {
      char *colon = strchr(pid_field, ':');
      if (colon == NULL)
        continue;
      char *end = NULL;
      long pid = strtol(colon + 1, &end, 10);
      if (end == colon + 1 || pid <= 0)
        continue;
      Nob_Cmd kill = {0};
      nob_cmd_append(&kill, "qs", "kill", nob_temp_sprintf("%ld", pid));
      if (!nob_cmd_run(&kill)) {
        ok = false;
        break;
      }
      stopped++;
    }
    if (!ok)
      break;
  }
  fclose(file);
  if (ok && stopped == 0)
    nob_log(NOB_INFO, "no NexusDotShell instance is running");
  return ok;
}

static bool collect_qml(Nob_Walk_Entry entry) {
  Nob_File_Paths *files = entry.data;
  if (entry.type == NOB_FILE_DIRECTORY
      && (strcmp(entry.path, ".git") == 0 || strcmp(entry.path, "./.git") == 0)) {
    *entry.action = NOB_WALK_SKIP;
    return true;
  }
  if (entry.type != NOB_FILE_REGULAR)
    return true;
  const char *name = nob_path_name(entry.path);
  size_t length = strlen(name);
  if (length < 4 || strcmp(name + length - 4, ".qml") != 0)
    return true;
  nob_da_append(files, nob_temp_strdup(entry.path));
  return true;
}

static bool lint_qml(void) {
  Nob_File_Paths files = {0};
  if (!nob_walk_dir(".", collect_qml, .data = &files))
    return false;
  Nob_Cmd command = {0};
  nob_cmd_append(&command, "qmllint", "-I", ".");
  for (size_t i = 0; i < files.count; i++)
    nob_cmd_append(&command, files.items[i]);
  return nob_cmd_run(&command);
}

static bool run_benchmark(void) {
  Nob_Cmd command = {0};
  nob_cmd_append(&command, "python3", "tools/gpu-probe/benchmark.py");
  return nob_cmd_run(&command);
}

static bool run_system_stats_benchmark(void) {
  Nob_Cmd command = {0};
  nob_cmd_append(&command, "python3", "tools/system-stats/benchmark.py");
  return nob_cmd_run(&command);
}

static void print_usage(const char *program) {
  nob_log(NOB_INFO, "usage: %s [build|run|run-detach|stop|lint|install-desktop|gpu-probe-benchmark|system-stats-benchmark]", program);
}

int main(int argc, char **argv) {
  NOB_GO_REBUILD_URSELF_PLUS(argc, argv, "nob.h");
  const char *target = argc > 1 ? argv[1] : "build";

  if (strcmp(target, "build") == 0)
    return build_helpers() ? 0 : 1;
  if (strcmp(target, "run") == 0)
    return run_shell(false) ? 0 : 1;
  if (strcmp(target, "run-detach") == 0)
    return run_shell(true) ? 0 : 1;
  if (strcmp(target, "stop") == 0)
    return stop_shell() ? 0 : 1;
  if (strcmp(target, "lint") == 0)
    return lint_qml() ? 0 : 1;
  if (strcmp(target, "install-desktop") == 0)
    return install_desktop_entry() ? 0 : 1;
  if (strcmp(target, "gpu-probe-benchmark") == 0)
    return run_benchmark() ? 0 : 1;
  if (strcmp(target, "system-stats-benchmark") == 0)
    return run_system_stats_benchmark() ? 0 : 1;

  print_usage(argv[0]);
  return 2;
}
