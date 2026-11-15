#define _POSIX_C_SOURCE 200809L

#include <ctype.h>
#include <dirent.h>
#include <errno.h>
#include <inttypes.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
  int pid;
  char pci[64];
  char driver[32];
  char client[64];
  uint64_t engine;
  uint64_t shared_kb;
  uint64_t local_kb;
} Record;

typedef struct {
  Record *items;
  size_t length;
  size_t capacity;
} RecordList;

static void copy_text(char *dst, size_t size, const char *src) {
  if (size == 0)
    return;
  size_t length = strlen(src);
  if (length >= size)
    length = size - 1;
  memcpy(dst, src, length);
  dst[length] = '\0';
}

static char *trim(char *text) {
  while (isspace((unsigned char)*text))
    text++;
  char *end = text + strlen(text);
  while (end > text && isspace((unsigned char)end[-1]))
    *--end = '\0';
  return text;
}

static bool parse_uint64(const char *text, uint64_t *value) {
  if (!isdigit((unsigned char)*text))
    return false;
  errno = 0;
  char *end = NULL;
  unsigned long long parsed = strtoull(text, &end, 10);
  if (errno != 0 || end == text || (*end != '\0' && !isspace((unsigned char)*end)))
    return false;
  *value = (uint64_t)parsed;
  return true;
}

static uint64_t saturating_add(uint64_t a, uint64_t b) {
  return UINT64_MAX - a < b ? UINT64_MAX : a + b;
}

static uint64_t memory_kb(const char *text) {
  uint64_t amount = 0;
  if (!parse_uint64(text, &amount))
    return 0;

  while (isdigit((unsigned char)*text))
    text++;
  while (isspace((unsigned char)*text))
    text++;
  if (strncmp(text, "MiB", 3) == 0)
    return amount > UINT64_MAX / 1024 ? UINT64_MAX : amount * 1024;
  if (strncmp(text, "GiB", 3) == 0)
    return amount > UINT64_MAX / 1048576 ? UINT64_MAX : amount * 1048576;
  return amount;
}

static bool numeric_name(const char *name) {
  if (*name == '\0')
    return false;
  for (const unsigned char *p = (const unsigned char *)name; *p; p++) {
    if (!isdigit(*p))
      return false;
  }
  return true;
}

static bool append_record(RecordList *records, const Record *record) {
  if (records->length == records->capacity) {
    size_t capacity = records->capacity == 0 ? 128 : records->capacity * 2;
    if (capacity < records->capacity || capacity > SIZE_MAX / sizeof(*records->items))
      return false;
    Record *items = realloc(records->items, capacity * sizeof(*items));
    if (items == NULL)
      return false;
    records->items = items;
    records->capacity = capacity;
  }
  records->items[records->length++] = *record;
  return true;
}

static bool read_fdinfo(const char *path, int pid, const char *fd, RecordList *records) {
  FILE *file = fopen(path, "r");
  if (file == NULL)
    return true;

  Record record = {.pid = pid};
  char *line = NULL;
  size_t line_capacity = 0;
  while (getline(&line, &line_capacity, file) >= 0) {
    char *colon = strchr(line, ':');
    if (colon == NULL)
      continue;
    *colon = '\0';
    const char *key = trim(line);
    char *value = trim(colon + 1);
    uint64_t amount = 0;

    if (strcmp(key, "drm-driver") == 0) {
      copy_text(record.driver, sizeof(record.driver), value);
    } else if (strcmp(key, "drm-pdev") == 0) {
      copy_text(record.pci, sizeof(record.pci), value);
    } else if (strcmp(key, "drm-client-id") == 0) {
      copy_text(record.client, sizeof(record.client), value);
    } else if (strncmp(key, "drm-engine-", 11) == 0
               && parse_uint64(value, &amount)) {
      record.engine = saturating_add(record.engine, amount);
    } else if (strncmp(key, "drm-total-system", 16) == 0) {
      record.shared_kb = saturating_add(record.shared_kb, memory_kb(value));
    } else if (strncmp(key, "drm-total-vram", 14) == 0
               || strncmp(key, "drm-total-local", 15) == 0) {
      record.local_kb = saturating_add(record.local_kb, memory_kb(value));
    }
  }
  free(line);
  fclose(file);

  if (record.driver[0] == '\0' || record.pci[0] == '\0'
      || (record.engine == 0 && record.shared_kb == 0 && record.local_kb == 0))
    return true;
  if (record.client[0] == '\0')
    copy_text(record.client, sizeof(record.client), fd);
  return append_record(records, &record);
}

static int compare_records(const void *left, const void *right) {
  const Record *a = left;
  const Record *b = right;
  if (a->pid != b->pid)
    return (a->pid > b->pid) - (a->pid < b->pid);
  int result = strcmp(a->pci, b->pci);
  if (result != 0)
    return result;
  result = strcmp(a->driver, b->driver);
  return result != 0 ? result : strcmp(a->client, b->client);
}

static bool same_key(const Record *a, const Record *b) {
  return a->pid == b->pid && strcmp(a->pci, b->pci) == 0
      && strcmp(a->driver, b->driver) == 0
      && strcmp(a->client, b->client) == 0;
}

static size_t merge_records(RecordList *records) {
  if (records->length > 1)
    qsort(records->items, records->length, sizeof(*records->items), compare_records);
  size_t output = 0;
  for (size_t i = 0; i < records->length; i++) {
    if (output > 0 && same_key(&records->items[output - 1], &records->items[i])) {
      Record *target = &records->items[output - 1];
      target->engine = target->engine > records->items[i].engine
          ? target->engine : records->items[i].engine;
      target->shared_kb = target->shared_kb > records->items[i].shared_kb
          ? target->shared_kb : records->items[i].shared_kb;
      target->local_kb = target->local_kb > records->items[i].local_kb
          ? target->local_kb : records->items[i].local_kb;
    } else {
      records->items[output++] = records->items[i];
    }
  }
  records->length = output;
  return output;
}

static bool scan_root(const char *proc_root, bool emit, size_t *record_count) {
  DIR *proc = opendir(proc_root);
  if (proc == NULL)
    return false;

  RecordList records = {0};
  struct dirent *pid_entry;
  bool ok = true;
  while ((pid_entry = readdir(proc)) != NULL) {
    if (!numeric_name(pid_entry->d_name))
      continue;
    char *end = NULL;
    long parsed_pid = strtol(pid_entry->d_name, &end, 10);
    if (*end != '\0' || parsed_pid <= 0 || parsed_pid > INT32_MAX)
      continue;

    char fdinfo_path[4096];
    int written = snprintf(fdinfo_path, sizeof(fdinfo_path), "%s/%s/fdinfo",
        proc_root, pid_entry->d_name);
    if (written < 0 || (size_t)written >= sizeof(fdinfo_path))
      continue;
    DIR *fdinfo = opendir(fdinfo_path);
    if (fdinfo == NULL)
      continue;

    struct dirent *fd_entry;
    while ((fd_entry = readdir(fdinfo)) != NULL) {
      if (!numeric_name(fd_entry->d_name))
        continue;
      char path[4096];
      written = snprintf(path, sizeof(path), "%s/%s", fdinfo_path, fd_entry->d_name);
      if (written < 0 || (size_t)written >= sizeof(path))
        continue;
      if (!read_fdinfo(path, (int)parsed_pid, fd_entry->d_name, &records)) {
        ok = false;
        break;
      }
    }
    closedir(fdinfo);
    if (!ok)
      break;
  }
  closedir(proc);

  if (ok) {
    *record_count = merge_records(&records);
    if (emit) {
      for (size_t i = 0; i < records.length; i++) {
        const Record *r = &records.items[i];
        printf("ENGINE|%d|%s|%s|%s|%" PRIu64 "|%" PRIu64 "|%" PRIu64 "\n",
            r->pid, r->pci, r->driver, r->client,
            r->engine, r->shared_kb, r->local_kb);
      }
    }
  }
  free(records.items);
  return ok;
}

static int parse_positive(const char *text, int *value) {
  char *end = NULL;
  long parsed = strtol(text, &end, 10);
  if (end == text || *end != '\0' || parsed <= 0 || parsed > 1000000)
    return 0;
  *value = (int)parsed;
  return 1;
}

int main(int argc, char **argv) {
  const char *proc_root = "/proc";
  int benchmark_iterations = 0;
  for (int i = 1; i < argc; i++) {
    if (strcmp(argv[i], "--proc-root") == 0 && i + 1 < argc) {
      proc_root = argv[++i];
    } else if (strcmp(argv[i], "--benchmark") == 0 && i + 1 < argc) {
      if (!parse_positive(argv[++i], &benchmark_iterations)) {
        fprintf(stderr, "invalid benchmark iteration count\n");
        return 2;
      }
    } else {
      fprintf(stderr, "usage: %s [--proc-root PATH] [--benchmark ITERATIONS]\n", argv[0]);
      return 2;
    }
  }

  if (benchmark_iterations > 0) {
    size_t total_records = 0;
    for (int i = 0; i < benchmark_iterations; i++) {
      size_t count = 0;
      if (!scan_root(proc_root, false, &count)) {
        perror("fdinfo scan");
        return 1;
      }
      total_records += count;
    }
    printf("samples=%d records=%zu\n", benchmark_iterations, total_records);
    return 0;
  }

  size_t count = 0;
  if (!scan_root(proc_root, true, &count)) {
    perror("fdinfo scan");
    return 1;
  }
  return 0;
}
