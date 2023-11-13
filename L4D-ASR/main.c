#include <stdbool.h>

#include "asr.h"
#include "intdefs.h"
#include "kvs.h"
#include "patterns.h"
#include "process.h"
#include "strutils.h"

#include "./libc/libc.h"

struct edict {
	int stateflags;
	int netserial;
	Address ent_networkable;
	Address ent_unknown;
};

struct campaign_context {
    Address campaign_context_name;
    int campaign_index;
    Address level_context_name;
    int unknown;
    Address chapter_display_name;
    Address map_name;
    Address versus_map_name;
    int map_index;
};

struct watcher_base {
    Address addr;
    int *offsets;
    int offset_count;
    int type_size;
};

#define WATCHER(type) { \
    Address addr; \
    int *offsets; \
    int offset_count; \
    int type_size; \
    typeof(type) curval; /* XXX: be aware of alignment here */ \
    typeof(type) oldval; \
}
#define DEF_WATCHER(type, name, ...) \
    struct WATCHER(type) name = { \
        .type_size = sizeof(type), \
        __VA_OPT__(.offsets = (int[]){__VA_ARGS__},) \
        __VA_OPT__(.offset_count = sizeof((int[]){__VA_ARGS__}) / sizeof(int)) \
    }

static DEF_WATCHER(bool, game_loading);
static DEF_WATCHER(bool, scr_draw_loading);
static DEF_WATCHER(Address, current_map);
static DEF_WATCHER(struct edict, player_edict, 88, sizeof(struct edict));
static DEF_WATCHER(float, restart_game_timer, 0, 0); // offset filled later
static DEF_WATCHER(bool, scoreboard_visible);
static DEF_WATCHER(int, sv_cheats);
static int off_m_fFlags = 0;
static int off_m_iHideHud = 0;
static Address kv_mission_metadata = 0;
static struct campaign_context g_ChapterItems[20] = {0};
static bool is_first_map = false;
static bool is_finale_map = false;
static bool has_split = true;
static char burhac_split[256] = {0};

static struct watcher_base *watchers[] = {
    (struct watcher_base*)&game_loading,
    (struct watcher_base*)&scr_draw_loading,
    (struct watcher_base*)&current_map,
    (struct watcher_base*)&player_edict,
    (struct watcher_base*)&restart_game_timer,
    (struct watcher_base*)&scoreboard_visible,
    (struct watcher_base*)&sv_cheats,
};

static ProcessId gamepid = 0;
static bool did_scan = false, got_memdata = false, is_l4d1 = false, is_l4d1_0;
static TimerState timer_state;

static struct settings {
    bool autostart_any_map;
    bool cutscene_split;
    bool redo_cutscene_split;
} settings;

#define INIT_SETTING(name, val, desc, ...) \
    settings.name = user_settings_add_bool(string(#name), string(desc), val) \
    __VA_OPT__(; user_settings_set_tooltip(string(#name), string(__VA_ARGS__)))

#define FETCH_SETTING(settings_map, name) do { \
    SettingValue x = settings_map_get(settings_map, string(#name)); \
    if (x) { \
        setting_value_get_bool(x, &settings.name); \
        setting_value_free(x); \
    } \
} while(0)

static void setup(void) {
    timer_state = timer_get_state();
    // rough testing on ASR 0.0.6 shows that this is actually a bit under 60Hz
    runtime_set_tick_rate(120);
    INIT_SETTING(autostart_any_map, false,
            "Allow timer to auto-start on any map",
            "Usually the timer only auto-starts on the first map of a campaign"
    );
    INIT_SETTING(cutscene_split, false,
            "Split when taking control at the start of a campaign",
            "Useful to track IL times during multi-campaign runs");
    INIT_SETTING(redo_cutscene_split, false,
            "Undo split if first map resets",
            "This ensures that IL times will always be tracked properly at the"
            " cost of having a longer campaign transition split");
}

static void clear_memdata(void) {
    did_scan = false;
    got_memdata = false;
    is_l4d1 = false;
    game_loading.addr = 0; game_loading.curval = 0;
    scr_draw_loading.addr = 0; scr_draw_loading.curval = 0;
    current_map.addr = 0; current_map.curval = 0;
    player_edict.addr = 0; player_edict.curval = (struct edict){0};
    restart_game_timer.addr = 0; restart_game_timer.curval = 0;
    restart_game_timer.offsets[1] = 0;
    scoreboard_visible.addr = 0; scoreboard_visible.curval = 0;
    sv_cheats.addr = 0; sv_cheats.curval = 0;
    off_m_fFlags = 0;
    off_m_iHideHud = 0;
    kv_mission_metadata = 0;
}

static bool scan_memdata(void) {
    Address engine = process_get_module_address(gamepid, string("engine.dll"));
    if (!engine) return false;
    Address client = process_get_module_address(gamepid, string("client.dll"));
    if (!client) return false;
    Address server = process_get_module_address(gamepid, string("server.dll"));
    if (!server) return false;

    did_scan = true;
    print("Started pointer/offset search");
    #define FIND(ptrn, mod, mod_size, out, ...) { \
        if (!find_##ptrn(gamepid, mod, mod_size, &out __VA_OPT__(,) __VA_ARGS__)) { \
            print("Failed to find "#ptrn); \
            return false; \
        } \
        printval(out); \
    }
    u64 eng_size = process_get_module_size(gamepid, string("engine.dll"));
    FIND(srvglobals, engine, eng_size, player_edict.addr);
    current_map.addr = player_edict.addr + 0x3c;
    FIND(game_loading, engine, eng_size, game_loading.addr)
    FIND(scr_draw_loading, engine, eng_size, scr_draw_loading.addr)
    FIND(sv_cheats, engine, eng_size, sv_cheats.addr)
    
    u64 srv_size = process_get_module_size(gamepid, string("server.dll"));
    FIND(m_fFlags, server, srv_size, off_m_fFlags)
    FIND(m_iHideHUD, server, srv_size, off_m_iHideHud)
    int off_timer;
    if (is_l4d1)
        FIND(off_restart_game_timer_l4d1, server, srv_size, off_timer)
    else
        FIND(off_restart_game_timer_l4d2, server, srv_size, off_timer)

    FIND(TheDirector, server, srv_size, restart_game_timer.addr)
    restart_game_timer.offsets[1] = off_timer;
    if ((is_l4d1_0 = (is_l4d1 && off_timer == 0x280))) // L4D 1.0
        FIND(g_ChapterItems, server, srv_size, g_ChapterItems, sizeof(g_ChapterItems))
    else
        FIND(kv_mission_metadata, server, srv_size, kv_mission_metadata)

    u64 cli_size = process_get_module_size(gamepid, string("client.dll"));
    FIND(scoreboard_visible, client, cli_size, scoreboard_visible.addr);
    if (!is_l4d1_0) {
        Address kvs_strings;
        FIND(kvs_strings, client, cli_size, kvs_strings);
        kvs_init(gamepid, kvs_strings);
    }

    #undef FIND
    print("Found all pointers and addresses!");
    got_memdata = true;
    return true;
}

static void update_watchers(void) {
    const int watcher_count = sizeof(watchers)/sizeof(struct watcher_base *);
    for (int i = 0; i < watcher_count; i++) {
        struct watcher_base *w = watchers[i];
        // Update the old value
        u8 *curval = (u8 *)w + sizeof(struct watcher_base);
        u8 *oldval = curval + w->type_size;
        memcpy(oldval, curval, w->type_size);
        // Try to dereference the pointer given all the offsets
        // and update the current value
        Address addr = w->addr;
        if (!addr) continue;
        if (w->offsets) {
            int j = 0;
            for (; j < w->offset_count - 1; j++) {
                if (!process_read_addr(gamepid, addr + w->offsets[j], &addr) &&
                        !addr)
                    goto update_end;
            }
            addr += w->offsets[j]; // add last offset without dereferencing
        }
        // Nothing to do if this fails
        process_read(gamepid, addr, curval, w->type_size);
update_end:
        continue;
    }
}

static void update_settings(void) {
    SettingsMap map = settings_map_load();
    FETCH_SETTING(map, autostart_any_map);
    FETCH_SETTING(map, cutscene_split);
    FETCH_SETTING(map, redo_cutscene_split);
    settings_map_free(map);
}

static bool campaign_maps(const char *map, int map_len, struct KeyValues *out) {
    Address mission_meta_addr;
    if (!process_read_addr(gamepid, kv_mission_metadata, &mission_meta_addr))
        return false;
    struct KeyValues mission_meta;
    if (!kvs_read(mission_meta_addr, &mission_meta)) return false;
    if (!kvs_getsubkey(&mission_meta, string("Missions"), &mission_meta))
        return false;

    struct KeyValues mission_kv;
    for (Address addr = mission_meta.child; addr; addr = mission_kv.next) {
        // if we can't read this, the iterations can't continue
        // for other failures, we can cope that this mission wasn't the one we
        // are looking for and keep iterating
        if (!kvs_read(addr, &mission_kv)) return false;
        struct KeyValues maps;
        if (!kvs_getsubkey(&mission_kv, string("modes"), &maps)) continue;
        if (!kvs_getsubkey(&maps, string("coop"), &maps)) continue;

        struct KeyValues map_kv;
        for (Address map_addr = maps.child; map_addr; map_addr = map_kv.next) {
            if (!kvs_read(map_addr, &map_kv)) break;
            struct KeyValues map_name;
            char strval[256];
            if (!kvs_getsubkey(&map_kv, string("Map"), &map_name)) continue;
            if (__builtin_expect(kvs_streq(&map_name, map, map_len), 0)) {
                *out = maps;
                return true;
            }
        }
    }
    return false;
}

static void kv_map_info(const char *curmap, int curmap_len) {
    struct KeyValues maps, tmp;
    if (!campaign_maps(curmap, curmap_len, &maps)) return;
    if (kvs_getsubkey(&maps, string("1"), &tmp)) {
        if (!kvs_getsubkey(&tmp, string("Map"), &tmp)) return;
        if ((is_first_map = kvs_streq(&tmp, curmap, curmap_len))) return;
    }

    // the day someone makes a campaign with more than 999 maps and breaks my
    // code, i'll personally go to their house to commit war crimes 
    if (!kvs_getsubkey(&maps, string("chapters"), &tmp)) return;
    char digit_buf[4] = {0, 0, 0, 0}, *digit = &digit_buf[3];
    int chapters = tmp.ival;
    while (chapters) {
        digit--;
        *digit = '0' + chapters % 10;
        chapters /= 10;
    }
    if (!kvs_getsubkey(&maps, digit, 3 - (digit - digit_buf), &tmp)) return;
    if (!kvs_getsubkey(&tmp, string("Map"), &tmp)) return;
    is_finale_map = kvs_streq(&tmp, curmap, curmap_len);
}

static void context_map_info(const char *curmap, int curmap_len) {
    for (int i = 0; i < 20; i++) {
        u8 map_name[32];
        if (!process_read(gamepid, g_ChapterItems[i].map_name, map_name, 32))
            return;
        if (memcmp(curmap, map_name, curmap_len + 1)) continue;
        is_first_map = g_ChapterItems[i].map_index == 1;
        is_finale_map = g_ChapterItems[i].map_index == 5;
        break;
    }
}

static void update_map_info(void) {
    static char oldmap[256] = {0};
    if (!current_map.curval)
        return;
    char curmap[256];
    int curmap_len;
    if (!process_read(gamepid, current_map.curval, (u8 *)curmap, 256)) return;
    curmap_len = strlen(curmap);
    if (!memcmp(curmap, oldmap, curmap_len + 1)) return;

    is_first_map = is_finale_map = false;
    memcpy(oldmap, curmap, curmap_len + 1);
    if (!curmap[0]) return;

    if (is_l4d1_0) context_map_info(curmap, curmap_len);
    else kv_map_info(curmap, curmap_len);
}

static bool check_runstart(int edict_flags, int player_flags) {
    static bool start_run = false;
    bool map_starting = scr_draw_loading.curval ||
            (restart_game_timer.curval > 0.0);
    if (__builtin_expect(!start_run, 1)) {
        start_run = map_starting;
        return false;
    }
    // edict gets changed immediately after RestartGame and the FROZEN flag
    // isn't set fast enough usually, which would trigger the timer before a
    // cutscene plays. checking for the FROZEN flag when the CHANGED flags are
    // down (and the edict is valid/full) delays the check long enough
    // 261 == FL_FULL_EDICT_CHANGED | FL_EDICT_FULL | FL_EDICT_CHANGED,
    // 4 == FL_EDICT_FULL, 32 == FL_FROZEN
    if (!map_starting && (edict_flags & 261) == 4 && !(player_flags & 32)) {
        start_run = false;
        return true;
    }
    return false;
}

static bool try_split(int edict_flags, int pl_flags, int pl_hidehud,
        int old_hidehud) {
    // Regular map transition detected by the scoreboard appearing
    if (scoreboard_visible.curval && !scoreboard_visible.oldval)
        return true;
    // Finale trigger detected by player being frozen and HUD going away
    // edict flags & FL_EDICT_FULL, to ensure valid player flags
    // player flags & FL_FROZEN
    // iHideHUD flags just changed from a small value to either 3961 or 3963
    // even though we poll faster than the game's tick rate, these flags stay
    // as 3963 for only a tick or two, so we check both reasonable values
    if (is_finale_map && edict_flags & 4 && pl_flags & 32 &&
            old_hidehud < 3961 && (pl_hidehud & ~2) == 3961)
        return true;
    // Optional split when gaining control at the start of a campaign
    // (except on the first split of the run). Check for control gain first to
    // ensure we don't miss a state change and mess up autostarting later
    if (check_runstart(edict_flags, pl_flags) && settings.cutscene_split &&
            has_split && is_first_map) {
        char curmap[256];
        int curmap_len;
        if (!process_read(gamepid, current_map.curval, (u8 *)curmap, 256))
            return false;
        curmap_len = strlen(curmap);
        // already split at the start of this map
        // decide what to do based on setting
        if (!memcmp(curmap, burhac_split, curmap_len + 1)) {
            if (!settings.redo_cutscene_split) return false;
            timer_undo_split();
            return true;
        }
        memcpy(burhac_split, curmap, curmap_len + 1);
        return true;
    }
    return false;
}

static void update_timer(void) {
    TimerState old_state = timer_state;
    timer_state = timer_get_state();

    int pl_flags = 0, ed_flags = player_edict.curval.stateflags;
    Address pl_ent = player_edict.curval.ent_unknown;
    if (__builtin_expect(pl_ent, 1))
        process_read(gamepid, pl_ent + off_m_fFlags, (u8 *)&pl_flags, 4);
    if (timer_state == TIMERSTATE_NOT_RUNNING) {
        if (!is_first_map && !settings.autostart_any_map) return;
        if (!check_runstart(ed_flags, pl_flags) || sv_cheats.curval) return;
        print("Run autostarted");
        timer_start();
        timer_state = TIMERSTATE_RUNNING;
        goto timer_started;
    }
    if (game_loading.curval != game_loading.oldval) {
        if (game_loading.curval) timer_pause_game_time();
        else timer_resume_game_time();
    }
    if (timer_state == TIMERSTATE_RUNNING) {
        if (__builtin_expect(old_state == TIMERSTATE_NOT_RUNNING, 0)) {
            print("Timer started");
timer_started:
            burhac_split[0] = 0;
            has_split = false;
            // pause the timer to indicate that game time is being used and
            // prevent the first split from being skipped on timer_split.
            // unpause the timer if needed
            timer_pause_game_time();
            if (!game_loading.curval) timer_resume_game_time();
        }
        static int pl_hidehud = 0;
        int old_hidehud = pl_hidehud;
        if (__builtin_expect(pl_ent, 1))
            process_read(gamepid, pl_ent+off_m_iHideHud, (u8 *)&pl_hidehud, 4);
        if (try_split(ed_flags, pl_flags, pl_hidehud, old_hidehud)) {
            has_split = true;
            timer_split();
        }
    }
}

__attribute__((export_name("update"))) void update(void) {
    static bool first_run = true;
    if (__builtin_expect(first_run, 0)) {
        first_run = false;
        setup();
        print("L4D2 autosplitter initialized");
    }
    if (__builtin_expect(gamepid == 0, 0)) {
        if (!(gamepid = process_attach(string("left4dead2.exe")))) {
            if (!(gamepid = process_attach(string("left4dead.exe"))))
                return;
            is_l4d1 = true;
        }
    }
    if (__builtin_expect(!process_is_open(gamepid), 0)) {
        process_detach(gamepid);
        gamepid = 0;
        // XXX: maybe pause game time?
        clear_memdata();
        return;
    }
    // search for addresses/offsets if needed
    // do nothing if searched but didn't find all data
    if (__builtin_expect(!got_memdata && (did_scan || !scan_memdata()), 0))
        return;

    // XXX: update settings before attaching if changing settings via code
    update_settings();
    update_watchers();
    update_map_info();
    update_timer();
}
