#ifndef ProcessBridge_h
#define ProcessBridge_h

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    int32_t pid;
    int32_t ppid;
    int64_t start_time_sec;
    int32_t start_time_usec;
    uint64_t cpu_time_ns;
    uint64_t physical_footprint_bytes;
    uint64_t bytes_read;
    uint64_t bytes_written;
    char name[256];
    char path[4096];
    char command_line[8192];
    char working_directory[4096];
} PWProcessSample;

typedef struct {
    uint64_t user_ticks;
    uint64_t system_ticks;
    uint64_t idle_ticks;
    uint64_t nice_ticks;
} PWCPUTicks;

typedef struct {
    uint64_t total_bytes;
    uint64_t used_bytes;
    uint64_t wired_bytes;
    uint64_t compressed_bytes;
    uint64_t swap_used_bytes;
    uint64_t swap_total_bytes;
    uint64_t reclaimable_bytes;
    uint64_t free_bytes;
    int32_t pressure_level;
} PWMemorySample;

/// Returns the number of PIDs written to buffer.
int32_t pw_list_pids(int32_t *buffer, int32_t max_count);

/// Returns true when a readable snapshot is available for the PID.
bool pw_read_process(int32_t pid, PWProcessSample *sample);

/// Stable accessors used by Swift. These avoid relying on how Clang imports
/// snake_case fields and fixed-size C character arrays in different Xcode versions.
int32_t pw_process_sample_ppid(const PWProcessSample *sample);
int64_t pw_process_sample_start_time_sec(const PWProcessSample *sample);
int32_t pw_process_sample_start_time_usec(const PWProcessSample *sample);
uint64_t pw_process_sample_cpu_time_ns(const PWProcessSample *sample);
uint64_t pw_process_sample_physical_footprint_bytes(const PWProcessSample *sample);
uint64_t pw_process_sample_bytes_read(const PWProcessSample *sample);
uint64_t pw_process_sample_bytes_written(const PWProcessSample *sample);
const char *pw_process_sample_name(const PWProcessSample *sample);
const char *pw_process_sample_path(const PWProcessSample *sample);
const char *pw_process_sample_command_line(const PWProcessSample *sample);
const char *pw_process_sample_working_directory(const PWProcessSample *sample);

/// Returns cumulative system CPU ticks.
bool pw_read_cpu_ticks(PWCPUTicks *ticks);
uint64_t pw_cpu_ticks_user(const PWCPUTicks *ticks);
uint64_t pw_cpu_ticks_system(const PWCPUTicks *ticks);
uint64_t pw_cpu_ticks_idle(const PWCPUTicks *ticks);
uint64_t pw_cpu_ticks_nice(const PWCPUTicks *ticks);

/// Returns a system memory snapshot. pressure_level uses 1=normal, 2=warning, 4=critical, -1=unavailable.
bool pw_read_memory(PWMemorySample *sample);
uint64_t pw_memory_total_bytes(const PWMemorySample *sample);
uint64_t pw_memory_used_bytes(const PWMemorySample *sample);
uint64_t pw_memory_wired_bytes(const PWMemorySample *sample);
uint64_t pw_memory_compressed_bytes(const PWMemorySample *sample);
uint64_t pw_memory_swap_used_bytes(const PWMemorySample *sample);
uint64_t pw_memory_swap_total_bytes(const PWMemorySample *sample);
uint64_t pw_memory_reclaimable_bytes(const PWMemorySample *sample);
uint64_t pw_memory_free_bytes(const PWMemorySample *sample);
int32_t pw_memory_pressure_level(const PWMemorySample *sample);

#ifdef __cplusplus
}
#endif

#endif /* ProcessBridge_h */
