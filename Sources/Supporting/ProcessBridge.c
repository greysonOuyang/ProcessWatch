#include "ProcessBridge.h"

#include <libproc.h>
#include <mach/mach.h>
#include <stdlib.h>
#include <string.h>
#include <sys/resource.h>
#include <sys/sysctl.h>
#include <sys/types.h>
#include <sys/proc_info.h>

static void pw_append_argument(char *output, size_t output_size, const char *argument, bool add_space) {
    if (output == NULL || output_size == 0 || argument == NULL || argument[0] == '\0') {
        return;
    }

    const size_t current_length = strnlen(output, output_size);
    if (current_length >= output_size - 1) {
        return;
    }

    char *destination = output + current_length;
    size_t remaining = output_size - current_length;
    if (add_space && current_length > 0 && remaining > 1) {
        *destination++ = ' ';
        *destination = '\0';
        remaining--;
    }

    const bool requires_quotes = strchr(argument, ' ') != NULL || strchr(argument, '\t') != NULL;
    if (requires_quotes && remaining > 1) {
        *destination++ = '"';
        *destination = '\0';
        remaining--;
    }

    strlcat(output, argument, output_size);

    if (requires_quotes) {
        const size_t updated_length = strnlen(output, output_size);
        if (updated_length < output_size - 1) {
            output[updated_length] = '"';
            output[updated_length + 1] = '\0';
        }
    }
}

static void pw_read_command_line(int32_t pid, char *output, size_t output_size) {
    if (output == NULL || output_size == 0) {
        return;
    }
    output[0] = '\0';

    int mib[3] = { CTL_KERN, KERN_PROCARGS2, pid };
    size_t buffer_size = 0;
    if (sysctl(mib, 3, NULL, &buffer_size, NULL, 0) != 0 || buffer_size <= sizeof(int)) {
        return;
    }

    char *buffer = calloc(1, buffer_size);
    if (buffer == NULL) {
        return;
    }

    if (sysctl(mib, 3, buffer, &buffer_size, NULL, 0) != 0) {
        free(buffer);
        return;
    }

    int argc = 0;
    memcpy(&argc, buffer, sizeof(argc));
    char *cursor = buffer + sizeof(argc);
    char *end = buffer + buffer_size;

    // Skip the executable path stored before argv[0].
    while (cursor < end && *cursor != '\0') {
        cursor++;
    }
    while (cursor < end && *cursor == '\0') {
        cursor++;
    }

    for (int index = 0; index < argc && cursor < end; index++) {
        char *argument = cursor;
        while (cursor < end && *cursor != '\0') {
            cursor++;
        }
        if (argument < end && argument[0] != '\0') {
            pw_append_argument(output, output_size, argument, index > 0);
        }
        while (cursor < end && *cursor == '\0') {
            cursor++;
        }
    }

    free(buffer);
}

int32_t pw_list_pids(int32_t *buffer, int32_t max_count) {
    if (buffer == NULL || max_count <= 0) {
        return 0;
    }

    const int bytes = proc_listpids(PROC_ALL_PIDS, 0, buffer, max_count * (int32_t)sizeof(int32_t));
    if (bytes <= 0) {
        return 0;
    }
    return bytes / (int32_t)sizeof(int32_t);
}

bool pw_read_process(int32_t pid, PWProcessSample *sample) {
    if (pid <= 0 || sample == NULL) {
        return false;
    }

    memset(sample, 0, sizeof(PWProcessSample));
    sample->pid = pid;

    rusage_info_v4 usage;
    memset(&usage, 0, sizeof(usage));
    const int result = proc_pid_rusage(pid, RUSAGE_INFO_V4, (rusage_info_t *)&usage);
    if (result != 0) {
        return false;
    }

    sample->cpu_time_ns = usage.ri_user_time + usage.ri_system_time;
    sample->physical_footprint_bytes = usage.ri_phys_footprint;
    sample->bytes_read = usage.ri_diskio_bytesread;
    sample->bytes_written = usage.ri_diskio_byteswritten;

    struct proc_bsdinfo bsd_info;
    memset(&bsd_info, 0, sizeof(bsd_info));
    const int bsd_bytes = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &bsd_info, sizeof(bsd_info));
    if (bsd_bytes == sizeof(bsd_info)) {
        sample->ppid = (int32_t)bsd_info.pbi_ppid;
        sample->start_time_sec = (int64_t)bsd_info.pbi_start_tvsec;
        sample->start_time_usec = (int32_t)bsd_info.pbi_start_tvusec;
    }

    char name_buffer[sizeof(sample->name)] = {0};
    if (proc_name(pid, name_buffer, (uint32_t)sizeof(name_buffer)) > 0) {
        strlcpy(sample->name, name_buffer, sizeof(sample->name));
    } else {
        strlcpy(sample->name, "Unknown", sizeof(sample->name));
    }

    char path_buffer[PROC_PIDPATHINFO_MAXSIZE] = {0};
    if (proc_pidpath(pid, path_buffer, sizeof(path_buffer)) > 0) {
        strlcpy(sample->path, path_buffer, sizeof(sample->path));
    }

    struct proc_vnodepathinfo vnode_info;
    memset(&vnode_info, 0, sizeof(vnode_info));
    const int vnode_bytes = proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &vnode_info, sizeof(vnode_info));
    if (vnode_bytes == sizeof(vnode_info)) {
        strlcpy(sample->working_directory, vnode_info.pvi_cdir.vip_path, sizeof(sample->working_directory));
    }

    pw_read_command_line(pid, sample->command_line, sizeof(sample->command_line));
    if (sample->command_line[0] == '\0' && sample->path[0] != '\0') {
        strlcpy(sample->command_line, sample->path, sizeof(sample->command_line));
    }

    return true;
}

int32_t pw_process_sample_ppid(const PWProcessSample *sample) {
    return sample == NULL ? 0 : sample->ppid;
}

int64_t pw_process_sample_start_time_sec(const PWProcessSample *sample) {
    return sample == NULL ? 0 : sample->start_time_sec;
}

int32_t pw_process_sample_start_time_usec(const PWProcessSample *sample) {
    return sample == NULL ? 0 : sample->start_time_usec;
}

uint64_t pw_process_sample_cpu_time_ns(const PWProcessSample *sample) {
    return sample == NULL ? 0 : sample->cpu_time_ns;
}

uint64_t pw_process_sample_physical_footprint_bytes(const PWProcessSample *sample) {
    return sample == NULL ? 0 : sample->physical_footprint_bytes;
}

uint64_t pw_process_sample_bytes_read(const PWProcessSample *sample) {
    return sample == NULL ? 0 : sample->bytes_read;
}

uint64_t pw_process_sample_bytes_written(const PWProcessSample *sample) {
    return sample == NULL ? 0 : sample->bytes_written;
}

const char *pw_process_sample_name(const PWProcessSample *sample) {
    return sample == NULL ? "" : sample->name;
}

const char *pw_process_sample_path(const PWProcessSample *sample) {
    return sample == NULL ? "" : sample->path;
}

const char *pw_process_sample_command_line(const PWProcessSample *sample) {
    return sample == NULL ? "" : sample->command_line;
}

const char *pw_process_sample_working_directory(const PWProcessSample *sample) {
    return sample == NULL ? "" : sample->working_directory;
}

bool pw_read_cpu_ticks(PWCPUTicks *ticks) {
    if (ticks == NULL) {
        return false;
    }

    host_cpu_load_info_data_t cpu_info;
    mach_msg_type_number_t count = HOST_CPU_LOAD_INFO_COUNT;
    const kern_return_t result = host_statistics(
        mach_host_self(),
        HOST_CPU_LOAD_INFO,
        (host_info_t)&cpu_info,
        &count
    );

    if (result != KERN_SUCCESS) {
        return false;
    }

    ticks->user_ticks = cpu_info.cpu_ticks[CPU_STATE_USER];
    ticks->system_ticks = cpu_info.cpu_ticks[CPU_STATE_SYSTEM];
    ticks->idle_ticks = cpu_info.cpu_ticks[CPU_STATE_IDLE];
    ticks->nice_ticks = cpu_info.cpu_ticks[CPU_STATE_NICE];
    return true;
}

bool pw_read_memory(PWMemorySample *sample) {
    if (sample == NULL) {
        return false;
    }
    memset(sample, 0, sizeof(PWMemorySample));
    sample->pressure_level = -1;

    uint64_t total_memory = 0;
    size_t total_size = sizeof(total_memory);
    if (sysctlbyname("hw.memsize", &total_memory, &total_size, NULL, 0) != 0) {
        return false;
    }

    vm_statistics64_data_t vm_stats;
    mach_msg_type_number_t count = HOST_VM_INFO64_COUNT;
    const kern_return_t stats_result = host_statistics64(
        mach_host_self(),
        HOST_VM_INFO64,
        (host_info64_t)&vm_stats,
        &count
    );
    if (stats_result != KERN_SUCCESS) {
        return false;
    }

    vm_size_t page_size = 0;
    if (host_page_size(mach_host_self(), &page_size) != KERN_SUCCESS) {
        return false;
    }

    const uint64_t page = (uint64_t)page_size;
    const uint64_t wired = (uint64_t)vm_stats.wire_count * page;
    const uint64_t active = (uint64_t)vm_stats.active_count * page;
    const uint64_t compressed = (uint64_t)vm_stats.compressor_page_count * page;
    const uint64_t inactive = (uint64_t)vm_stats.inactive_count * page;
    const uint64_t speculative = (uint64_t)vm_stats.speculative_count * page;
    const uint64_t purgeable = (uint64_t)vm_stats.purgeable_count * page;
    const uint64_t free = (uint64_t)vm_stats.free_count * page;
    const uint64_t used = wired + active + compressed;

    struct xsw_usage swap_usage;
    memset(&swap_usage, 0, sizeof(swap_usage));
    size_t swap_size = sizeof(swap_usage);
    if (sysctlbyname("vm.swapusage", &swap_usage, &swap_size, NULL, 0) == 0) {
        sample->swap_used_bytes = swap_usage.xsu_used;
        sample->swap_total_bytes = swap_usage.xsu_total;
    }

    int pressure_level = -1;
    size_t pressure_size = sizeof(pressure_level);
    if (sysctlbyname("kern.memorystatus_vm_pressure_level", &pressure_level, &pressure_size, NULL, 0) == 0) {
        sample->pressure_level = pressure_level;
    }

    sample->total_bytes = total_memory;
    sample->used_bytes = used > total_memory ? total_memory : used;
    sample->wired_bytes = wired;
    sample->compressed_bytes = compressed;
    sample->reclaimable_bytes = inactive + speculative + purgeable;
    sample->free_bytes = free;
    return true;
}

uint64_t pw_cpu_ticks_user(const PWCPUTicks *ticks) {
    return ticks == NULL ? 0 : ticks->user_ticks;
}

uint64_t pw_cpu_ticks_system(const PWCPUTicks *ticks) {
    return ticks == NULL ? 0 : ticks->system_ticks;
}

uint64_t pw_cpu_ticks_idle(const PWCPUTicks *ticks) {
    return ticks == NULL ? 0 : ticks->idle_ticks;
}

uint64_t pw_cpu_ticks_nice(const PWCPUTicks *ticks) {
    return ticks == NULL ? 0 : ticks->nice_ticks;
}

uint64_t pw_memory_total_bytes(const PWMemorySample *sample) {
    return sample == NULL ? 0 : sample->total_bytes;
}

uint64_t pw_memory_used_bytes(const PWMemorySample *sample) {
    return sample == NULL ? 0 : sample->used_bytes;
}

uint64_t pw_memory_wired_bytes(const PWMemorySample *sample) {
    return sample == NULL ? 0 : sample->wired_bytes;
}

uint64_t pw_memory_compressed_bytes(const PWMemorySample *sample) {
    return sample == NULL ? 0 : sample->compressed_bytes;
}

uint64_t pw_memory_swap_used_bytes(const PWMemorySample *sample) {
    return sample == NULL ? 0 : sample->swap_used_bytes;
}

uint64_t pw_memory_swap_total_bytes(const PWMemorySample *sample) {
    return sample == NULL ? 0 : sample->swap_total_bytes;
}

uint64_t pw_memory_reclaimable_bytes(const PWMemorySample *sample) {
    return sample == NULL ? 0 : sample->reclaimable_bytes;
}

uint64_t pw_memory_free_bytes(const PWMemorySample *sample) {
    return sample == NULL ? 0 : sample->free_bytes;
}

int32_t pw_memory_pressure_level(const PWMemorySample *sample) {
    return sample == NULL ? -1 : sample->pressure_level;
}

