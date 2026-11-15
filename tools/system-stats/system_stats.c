#define _POSIX_C_SOURCE 200809L

#include <ctype.h>
#include <dirent.h>
#include <errno.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
  char **items;
  size_t length;
  size_t capacity;
} StringList;

static bool join_path(char *destination, size_t capacity, const char *root,
                      const char *suffix) {
  size_t root_length = strlen(root);
  const char *separator = root_length > 0 && root[root_length - 1] == '/' ? "" : "/";
  int length = snprintf(destination, capacity, "%s%s%s", root, separator, suffix);
  return length >= 0 && (size_t)length < capacity;
}

static char *trim_line_end(char *line) {
  size_t length = strlen(line);
  while (length > 0 && (line[length - 1] == '\n' || line[length - 1] == '\r'))
    line[--length] = '\0';
  return line;
}

static bool is_cpu_name(const char *name) {
  if (strncmp(name, "cpu", 3) != 0)
    return false;
  for (const unsigned char *p = (const unsigned char *)name + 3; *p; p++) {
    if (!isdigit(*p))
      return false;
  }
  return true;
}

static bool emit_cpu_counters(const char *proc_root) {
  char path[4096];
  if (!join_path(path, sizeof(path), proc_root, "stat"))
    return false;
  FILE *file = fopen(path, "r");
  if (file == NULL)
    return false;

  char *line = NULL;
  size_t capacity = 0;
  ssize_t length;
  while ((length = getline(&line, &capacity, file)) >= 0) {
    (void)length;
    char *save = NULL;
    char *name = strtok_r(line, " \t\r\n", &save);
    if (name == NULL || !is_cpu_name(name))
      continue;

    printf("CPU %s", name);
    for (char *value = strtok_r(NULL, " \t\r\n", &save);
         value != NULL;
         value = strtok_r(NULL, " \t\r\n", &save))
      printf(" %s", value);
    putchar('\n');
  }
  bool ok = !ferror(file);
  free(line);
  fclose(file);
  return ok;
}

static bool wanted_memory_key(const char *key) {
  static const char *const keys[] = {
    "MemTotal:", "MemAvailable:", "MemFree:", "Buffers:", "Cached:",
    "SReclaimable:", "Shmem:", "SwapTotal:", "SwapFree:"
  };
  for (size_t i = 0; i < sizeof(keys) / sizeof(keys[0]); i++) {
    if (strcmp(key, keys[i]) == 0)
      return true;
  }
  return false;
}

static bool emit_memory(const char *proc_root) {
  char path[4096];
  if (!join_path(path, sizeof(path), proc_root, "meminfo"))
    return false;
  FILE *file = fopen(path, "r");
  if (file == NULL)
    return false;

  char *line = NULL;
  size_t capacity = 0;
  ssize_t length;
  while ((length = getline(&line, &capacity, file)) >= 0) {
    (void)length;
    char *save = NULL;
    char *key = strtok_r(line, " \t\r\n", &save);
    char *value = strtok_r(NULL, " \t\r\n", &save);
    if (key != NULL && value != NULL && wanted_memory_key(key))
      printf("MEM %s %s\n", key, value);
  }
  bool ok = !ferror(file);
  free(line);
  fclose(file);
  return ok;
}

static bool cpu_info_key(const char *key) {
  return strcmp(key, "model name") == 0
      || strcmp(key, "Hardware") == 0
      || strcmp(key, "Processor") == 0;
}

static bool emit_cpu_model_and_cores(const char *proc_root) {
  char path[4096];
  if (!join_path(path, sizeof(path), proc_root, "cpuinfo"))
    return false;
  FILE *file = fopen(path, "r");
  if (file == NULL)
    return false;

  bool model_emitted = false;
  size_t cores = 0;
  char *line = NULL;
  size_t capacity = 0;
  ssize_t length;
  while ((length = getline(&line, &capacity, file)) >= 0) {
    (void)length;
    trim_line_end(line);
    if (strncmp(line, "processor", 9) == 0
        && (line[9] == ':' || isspace((unsigned char)line[9])))
      cores++;

    char *colon = strchr(line, ':');
    if (colon == NULL || model_emitted)
      continue;
    *colon = '\0';
    char *key = line;
    while (isspace((unsigned char)*key))
      key++;
    char *key_end = key + strlen(key);
    while (key_end > key && isspace((unsigned char)key_end[-1]))
      *--key_end = '\0';
    if (!cpu_info_key(key))
      continue;

    char *model = colon + 1;
    while (*model == ' ' || *model == '\t')
      model++;
    printf("MODEL %s\n", model);
    model_emitted = true;
  }
  bool ok = !ferror(file);
  free(line);
  fclose(file);
  if (!ok)
    return false;
  printf("CORES %zu\n", cores);
  return true;
}

static bool append_string(StringList *list, const char *value) {
  if (list->length == list->capacity) {
    size_t capacity = list->capacity == 0 ? 8 : list->capacity * 2;
    if (capacity < list->capacity || capacity > SIZE_MAX / sizeof(*list->items))
      return false;
    char **items = realloc(list->items, capacity * sizeof(*items));
    if (items == NULL)
      return false;
    list->items = items;
    list->capacity = capacity;
  }
  list->items[list->length] = strdup(value);
  if (list->items[list->length] == NULL)
    return false;
  list->length++;
  return true;
}

static int compare_strings(const void *left, const void *right) {
  const char *const *a = left;
  const char *const *b = right;
  return strcmp(*a, *b);
}

static void free_strings(StringList *list) {
  for (size_t i = 0; i < list->length; i++)
    free(list->items[i]);
  free(list->items);
}

static bool read_value(const char *path, char *value, size_t capacity) {
  FILE *file = fopen(path, "r");
  if (file == NULL)
    return false;
  bool ok = fgets(value, (int)capacity, file) != NULL;
  fclose(file);
  if (ok)
    trim_line_end(value);
  return ok;
}

static bool parse_temperature(const char *text, long *temperature) {
  if (*text == '\0')
    return false;
  for (const unsigned char *p = (const unsigned char *)text; *p; p++) {
    if (!isdigit(*p))
      return false;
  }
  errno = 0;
  char *end = NULL;
  long value = strtol(text, &end, 10);
  if (errno != 0 || end == text || *end != '\0' || value < 20000 || value > 120000)
    return false;
  *temperature = value / 1000;
  return true;
}

static long find_temperature(const char *sys_root) {
  char thermal_path[4096];
  if (!join_path(thermal_path, sizeof(thermal_path), sys_root, "class/thermal"))
    return 0;
  DIR *directory = opendir(thermal_path);
  if (directory == NULL)
    return 0;

  StringList zones = {0};
  struct dirent *entry;
  bool allocation_failed = false;
  while ((entry = readdir(directory)) != NULL) {
    if (strncmp(entry->d_name, "thermal_zone", 12) == 0
        && !append_string(&zones, entry->d_name)) {
      allocation_failed = true;
      break;
    }
  }
  closedir(directory);
  if (allocation_failed) {
    free_strings(&zones);
    return 0;
  }
  if (zones.length > 1)
    qsort(zones.items, zones.length, sizeof(*zones.items), compare_strings);

  static const char *const preferred_types[] = {
    "x86_pkg_temp", "TCPU_PCI", "TCPU"
  };
  long result = 0;
  for (size_t type = 0; type < sizeof(preferred_types) / sizeof(preferred_types[0]); type++) {
    for (size_t zone = 0; zone < zones.length; zone++) {
      char suffix[4096];
      char path[4096];
      int length = snprintf(suffix, sizeof(suffix), "class/thermal/%s/type", zones.items[zone]);
      if (length < 0 || (size_t)length >= sizeof(suffix)
          || !join_path(path, sizeof(path), sys_root, suffix))
        continue;
      char value[256];
      if (!read_value(path, value, sizeof(value))
          || strcmp(value, preferred_types[type]) != 0)
        continue;

      length = snprintf(suffix, sizeof(suffix), "class/thermal/%s/temp", zones.items[zone]);
      if (length < 0 || (size_t)length >= sizeof(suffix)
          || !join_path(path, sizeof(path), sys_root, suffix)
          || !read_value(path, value, sizeof(value))
          || !parse_temperature(value, &result))
        continue;
      goto done;
    }
  }

done:
  free_strings(&zones);
  return result;
}

static bool parse_arguments(int argc, char **argv, const char **proc_root,
                            const char **sys_root) {
  *proc_root = "/proc";
  *sys_root = "/sys";
  for (int i = 1; i < argc; i++) {
    if (strcmp(argv[i], "--proc-root") == 0 && i + 1 < argc) {
      *proc_root = argv[++i];
    } else if (strcmp(argv[i], "--sys-root") == 0 && i + 1 < argc) {
      *sys_root = argv[++i];
    } else {
      fprintf(stderr, "usage: %s [--proc-root PATH] [--sys-root PATH]\n", argv[0]);
      return false;
    }
  }
  return true;
}

int main(int argc, char **argv) {
  const char *proc_root;
  const char *sys_root;
  if (!parse_arguments(argc, argv, &proc_root, &sys_root))
    return 2;
  if (!emit_cpu_counters(proc_root)
      || !emit_memory(proc_root)
      || !emit_cpu_model_and_cores(proc_root))
    return 1;
  printf("TEMP %ld\n", find_temperature(sys_root));
  return 0;
}
