#ifndef ASR_H
#define ASR_H

#include <stdbool.h>

#include "intdefs.h"

typedef u64 SettingsMap;
typedef u64 SettingValue;

typedef u32 TimerState;
enum TimeStateValues {
    /// The timer is not running.
    TIMERSTATE_NOT_RUNNING = 0,
    /// The timer is running.
    TIMERSTATE_RUNNING = 1,
    /// The timer started but got paused. This is separate from the game
    /// time being paused. Game time may even always be paused.
    TIMERSTATE_PAUSED = 2,
    /// The timer has ended, but didn't get reset yet.
    TIMERSTATE_ENDED = 3,
};

typedef u64 MemoryRangeFlags;
enum MemoryRangeFlagsValues {
    /// The memory range is readable.
    MEMORYRANGEFLAGS_READ = 1 << 1,
    /// The memory range is writable.
    MEMORYRANGEFLAGS_WRITE = 1 << 2,
    /// The memory range is executable.
    MEMORYRANGEFLAGS_EXECUTE = 1 << 3,
    /// The memory range has a file path.
    MEMORYRANGEFLAGS_PATH = 1 << 4,
};

/// Gets the state that the timer currently is in.
TimerState timer_get_state(void);

/// Starts the timer.
void timer_start(void);
/// Splits the current segment.
void timer_split(void);
/// Skips the current split.
void timer_skip_split(void);
/// Undoes the previous split.
void timer_undo_split(void);
/// Resets the timer.
void timer_reset(void);
/// Sets a custom key value pair. This may be arbitrary information that
/// the auto splitter wants to provide for visualization. The pointers need to
/// point to valid UTF-8 encoded text with the respective given length.
void timer_set_variable(
    const char *key_ptr,
    usize key_len,
    const char *value_ptr,
    usize value_len
);

/// Sets the game time.
void timer_set_game_time(i64 secs, i32 nanos);
/// Pauses the game time. This does not pause the timer, only the
/// automatic flow of time for the game time.
void timer_pause_game_time(void);
/// Resumes the game time. This does not resume the timer, only the
/// automatic flow of time for the game time.
void timer_resume_game_time(void);

/// Attaches to a process based on its name. Returns 0 if the process can't be
/// found.
ProcessId process_attach(const char *name_ptr, usize name_len);
/// Attaches to a process based on its process id. Returns 0 if the process
/// can't be found.
ProcessId process_attach_by_pid(ProcessId pid);
/// Detaches from a process.
void process_detach(ProcessId process);
/// Lists processes based on their name. The name pointer needs to point to
/// valid UTF-8 encoded text with the given length. Returns `false` if
/// listing the processes failed. If it was successful, the buffer is now
/// filled with the process ids. They are in no specific order. The
/// `list_len_ptr` will be updated to the amount of process ids that were
/// found. If this is larger than the original value provided, the buffer
/// provided was too small and not all process ids could be stored. This is
/// still considered successful and can optionally be treated as an error
/// condition by the caller by checking if the length increased and
/// potentially reallocating a larger buffer. If the length decreased after
/// the call, the buffer was larger than needed and the remaining entries
/// are untouched.
bool process_list_by_name(
    const char *name_ptr,
    usize name_len,
    ProcessId *list_ptr,
    usize *list_len_ptr
);
/// Checks whether is a process is still open. You should detach from a
/// process and stop using it if this returns `false`.
bool process_is_open(ProcessId process);
/// Reads memory from a process at the address given. This will write
/// the memory to the buffer given. Returns `false` if this fails.
bool process_read(ProcessId process, u64 address, u8 *buf_ptr, usize buf_len);

/// Gets the address of a module in a process. The pointer needs to point to
/// valid UTF-8 encoded text with the given length.
u64 process_get_module_address(
    ProcessId process,
    const char *name_ptr,
    usize name_len
);
/// Gets the size of a module in a process. The pointer needs to point to
/// valid UTF-8 encoded text with the given length.
u64 process_get_module_size(
    ProcessId process,
    const char *name_ptr,
    usize name_len
);
/// Stores the file system path of a module in a process in the buffer
/// given. The pointer to the module name needs to point to valid UTF-8
/// encoded text with the given length. The path is a path that is
/// accessible through the WASI file system, so a Windows path of
/// `C:\foo\bar.exe` would be returned as `/mnt/c/foo/bar.exe`. Returns
/// `false` if the buffer is too small. After this call, no matter whether
/// it was successful or not, the `buf_len_ptr` will be set to the required
/// buffer size. If `false` is returned and the `buf_len_ptr` got set to 0,
/// the path or the module does not exist or it failed to get read. The path
/// is guaranteed to be valid UTF-8 and is not nul-terminated.
bool process_get_module_path(
    ProcessId process,
    const char *name_ptr,
    usize name_len,
    char *buf_ptr,
    usize *buf_len_ptr
);
/// Stores the file system path of the executable in the buffer given. The
/// path is a path that is accessible through the WASI file system, so a
/// Windows path of `C:\foo\bar.exe` would be returned as
/// `/mnt/c/foo/bar.exe`. Returns `false` if the buffer is too small. After
/// this call, no matter whether it was successful or not, the `buf_len_ptr`
/// will be set to the required buffer size. If `false` is returned and the
/// `buf_len_ptr` got set to 0, the path does not exist or failed to get
/// read. The path is guaranteed to be valid UTF-8 and is not nul-terminated.
bool process_get_path(ProcessId process, char *buf_ptr, usize *buf_len_ptr);
/// Gets the number of memory ranges in a given process.
u64 process_get_memory_range_count(ProcessId process);
/// Gets the start address of a memory range by its index.
u64 process_get_memory_range_address(ProcessId process, u64 idx);
/// Gets the size of a memory range by its index.
u64 process_get_memory_range_size(ProcessId process, u64 idx);
/// Gets the flags of a memory range by its index.
MemoryRangeFlags process_get_memory_range_flags(ProcessId process, u64 idx);

/// Sets the tick rate of the runtime. This influences the amount of
/// times the `update` function is called per second.
void runtime_set_tick_rate(double ticks_per_second);
/// Prints a log message for debugging purposes. The pointer needs to point
/// to valid UTF-8 encoded text with the given length.
void runtime_print_message(const char *text_ptr, usize text_len);
/// Stores the name of the operating system that the runtime is running
/// on in the buffer given. Returns `false` if the buffer is too small.
/// After this call, no matter whether it was successful or not, the
/// `buf_len_ptr` will be set to the required buffer size. The name is
/// guaranteed to be valid UTF-8 and is not nul-terminated.
/// Example values: `windows`, `linux`, `macos`
bool runtime_get_os(char *buf_ptr, usize *buf_len_ptr);
/// Stores the name of the architecture that the runtime is running on
/// in the buffer given. Returns `false` if the buffer is too small.
/// After this call, no matter whether it was successful or not, the
/// `buf_len_ptr` will be set to the required buffer size. The name is
/// guaranteed to be valid UTF-8 and is not nul-terminated.
/// Example values: `x86`, `x86_64`, `arm`, `aarch64`
bool runtime_get_arch(char *buf_ptr, usize *buf_len_ptr);

/// Adds a new boolean setting that the user can modify. This will return
/// either the specified default value or the value that the user has set.
/// The key is used to store the setting and needs to be unique across all
/// types of settings. The pointers need to point to valid UTF-8 encoded
/// text with the respective given length.
bool user_settings_add_bool(
    const char *key_ptr,
    usize key_len,
    const char *description_ptr,
    usize description_len,
    bool default_value
);
/// Adds a new title to the user settings. This is used to group settings
/// together. The heading level determines the size of the title. The top
/// level titles use a heading level of 0. The key needs to be unique across
/// all types of settings. The pointers need to point to valid UTF-8 encoded
/// text with the respective given length.
void user_settings_add_title(
    const char *key_ptr,
    usize key_len,
    const char *description_ptr,
    usize description_len,
    u32 heading_level
);
/// Adds a tooltip to a setting based on its key. A tooltip is useful for
/// explaining the purpose of a setting to the user. The pointers need to
/// point to valid UTF-8 encoded text with the respective given length.
void user_settings_set_tooltip(
    const char *key_ptr,
    usize key_len,
    const char *tooltip_ptr,
    usize tooltip_len
);

/// Creates a new settings map. You own the settings map and are responsible
/// for freeing it.
SettingsMap settings_map_new(void);
/// Frees a settings map.
void settings_map_free(SettingsMap map);
/// Loads a copy of the currently set global settings map. Any changes to it
/// are only perceived if it's stored back. You own the settings map and are
/// responsible for freeing it.
SettingsMap settings_map_load(void);
/// Stores a copy of the settings map as the new global settings map. This
/// will overwrite the previous global settings map. You still retain
/// ownership of the map, which means you still need to free it. There's a
/// chance that the settings map was changed in the meantime, so those
/// changes could get lost. Prefer using `settings_map_store_if_unchanged`
/// if you want to avoid that.
void settings_map_store(SettingsMap map);
/// Stores a copy of the new settings map as the new global settings map if
/// the map has not changed in the meantime. This is done by comparing the
/// old map. You still retain ownership of both maps, which means you still
/// need to free them. Returns `true` if the map was stored successfully.
/// Returns `false` if the map was changed in the meantime.
bool settings_map_store_if_unchanged(SettingsMap old_map, SettingsMap new_map);
/// Copies a settings map. No changes inside the copy affect the original
/// settings map. You own the new settings map and are responsible for
/// freeing it.
SettingsMap settings_map_copy(SettingsMap map);
/// Inserts a copy of the setting value into the settings map based on the
/// key. If the key already exists, it will be overwritten. You still retain
/// ownership of the setting value, which means you still need to free it.
/// The pointer needs to point to valid UTF-8 encoded text with the given
/// length.
void settings_map_insert(
    SettingsMap map,
    const char *key_ptr,
    usize key_len,
    SettingValue value
);
/// Gets a copy of the setting value from the settings map based on the key.
/// Returns `None` if the key does not exist. Any changes to it are only
/// perceived if it's stored back. You own the setting value and are
/// responsible for freeing it. The pointer needs to point to valid UTF-8
/// encoded text with the given length.
SettingValue settings_map_get(
    SettingsMap map,
    const char *key_ptr,
    usize key_len
);

/// Creates a new setting value from a settings map. The value is a copy of
/// the settings map. Any changes to the original settings map afterwards
/// are not going to be perceived by the setting value. You own the setting
/// value and are responsible for freeing it. You also retain ownership of
/// the settings map, which means you still need to free it.
SettingValue setting_value_new_map(SettingsMap value);
/// Creates a new boolean setting value. You own the setting value and are
/// responsible for freeing it.
SettingValue setting_value_new_bool(bool value);
/// Creates a new string setting value. The pointer needs to point to valid
/// UTF-8 encoded text with the given length. You own the setting value and
/// are responsible for freeing it.
SettingValue setting_value_new_string(const char *value_ptr, usize value_len);
/// Frees a setting value.
void setting_value_free(SettingValue value);
/// Gets the value of a setting value as a settings map by storing it into
/// the pointer provided. Returns `false` if the setting value is not a
/// settings map. No value is stored into the pointer in that case. No
/// matter what happens, you still retain ownership of the setting value,
/// which means you still need to free it. You own the settings map and are
/// responsible for freeing it.
bool setting_value_get_map(SettingValue value, SettingsMap *value_ptr);
/// Gets the value of a boolean setting value by storing it into the pointer
/// provided. Returns `false` if the setting value is not a boolean. No
/// value is stored into the pointer in that case. No matter what happens,
/// you still retain ownership of the setting value, which means you still
/// need to free it.
bool setting_value_get_bool(SettingValue value, bool *value_ptr);
/// Gets the value of a string setting value by storing it into the buffer
/// provided. Returns `false` if the buffer is too small or if the setting
/// value is not a string. After this call, no matter whether it was
/// successful or not, the `buf_len_ptr` will be set to the required buffer
/// size. If `false` is returned and the `buf_len_ptr` got set to 0, the
/// setting value is not a string. The string is guaranteed to be valid
/// UTF-8 and is not nul-terminated. No matter what happens, you still
/// retain ownership of the setting value, which means you still need to
/// free it.
bool setting_value_get_string(
    SettingValue value,
    char *buf_ptr,
    usize *buf_len_ptr
);

#endif /* ASR_H */
