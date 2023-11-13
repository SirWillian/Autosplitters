#include "asr.h"
#include "intdefs.h"
#include "process.h"
#include "strutils.h"

#include "./libc/libc.h"

static bool match_string(ProcessId gamepid, Address str_ref, const char *str,
        int str_len) {
    Address str_addr;
    if (!process_read_addr(gamepid, str_ref, &str_addr))
        return false;
    u8 str_value[64];
    if (!process_read(gamepid, str_addr, str_value, str_len + 1))
        return false;
    return !memcmp(str_value, str, str_len);
}

#define _PTRN_ARRAY(...) \
    (unsigned char[]){__VA_ARGS__}, sizeof((unsigned char[]){__VA_ARGS__})

// _Host_SetGlobalTime writes to g_ServerGlobalVariables
static const struct byte_pattern ptrn_srvglobals = {
    _PTRN_ARRAY(0xF3, 0x0F, 0x10, 0x05, 0x00, 0x00, 0x00, 0x00, 0xA1, 0x00,
                0x00, 0x00, 0x00, 0xF3, 0x0F, 0x11, 0x05, 0x00, 0x00, 0x00,
                0x00, 0xF3, 0x0F, 0x10, 0x05),
    _PTRN_ARRAY(4, 5, 6, 7, 9, 10, 11, 12, 17, 18, 19, 20)
};
static inline bool find_srvglobals(ProcessId proc, Address eng, u64 eng_size,
        Address *out) {
    Address srvglobals = process_scan(proc, &ptrn_srvglobals, eng, eng_size);
    return process_read_addr(proc, srvglobals + 17, out);
}

// g_bNeedPresetRestore in the sound system seems to reasonably reflect every
// load the game does
static const struct byte_pattern ptrn_game_loading = {
    _PTRN_ARRAY(0x38, 0x1D, 0x00, 0x00, 0x00, 0x00, 0x0F, 0x85, 0x00, 0x00,
                0x00, 0x00, 0x56, 0x53),
    _PTRN_ARRAY(2, 3, 4, 5, 8, 9, 10, 11)
};
static inline bool find_game_loading(ProcessId proc, Address eng, u64 eng_size,
        Address *out) {
    Address load_addr = process_scan(proc, &ptrn_game_loading, eng, eng_size);
    return process_read_addr(proc, load_addr + 2, out);
}

// Host_RunFrame reads scr_drawloading
static const struct byte_pattern ptrn_scr_draw_loading = {
    _PTRN_ARRAY(0x83, 0xEC, 0x10, 0x80, 0x3D, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x75, 0x00, 0x83, 0x3D, 0x00, 0x00, 0x00, 0x00, 0x02),
    _PTRN_ARRAY(5, 6, 7, 8, 11, 14, 15, 16, 17)
};
static inline bool find_scr_draw_loading(ProcessId gamepid, Address eng,
        u64 eng_size, Address *out) {
    Address scr = process_scan(gamepid, &ptrn_scr_draw_loading, eng, eng_size);
    return process_read_addr(gamepid, scr + 5, out);
}

// Host_Init checks command line params to see if it should enable sv_cheats
static const struct byte_pattern ptrn_sv_cheats = {
    _PTRN_ARRAY(0xFF, 0xD0, 0x85, 0xC0, 0x75, 0x00, 0x6A, 0x01),
    _PTRN_ARRAY(5)
};
static inline bool find_sv_cheats(ProcessId proc, Address eng, u64 eng_size,
        Address *out) {
    // This address points to the ConVar vtable in the sv_cheats object
    Address sv_cheats_ptr = process_scan(proc, &ptrn_sv_cheats, eng, eng_size);
    if (!process_read_addr(proc, sv_cheats_ptr + 9, out)) return false;
    *out += (0x30 - 0x18); // offset to cvar's int value from cvar vt
    return true;
}
// Aciidz found this pattern. Don't remember what it points to exactly,
// but it works
// const struct byte_pattern ptrn_sv_cheats = {
//     _PTRN_ARRAY(0x83, 0x3D, 0x00, 0x00, 0x00, 0x00, 0x00, 0x56, 0x57),
//     _PTRN_ARRAY(2, 3, 4, 5)
// };

// Fishing this out of the server's DT_BasePlayer SendTable
// DT_Infected also matches this pattern but the member offset is the same
// L4D1 pushes 0x401 on the first instruction, L4D2 pushes 0x4001
static const struct byte_pattern ptrn_m_fFlags = {
    _PTRN_ARRAY(0x68, 0x01, 0x00, 0x00, 0x00, 0x6a, 0x0a, 0x6a, 0x04, 0x68,
                0x00, 0x00, 0x00, 0x00, 0x68),
    _PTRN_ARRAY(2, 3, 10, 11, 12, 13)
};
static inline bool find_m_fFlags(ProcessId proc, Address srv, u64 srv_size,
        int *out) {
    Address m_fFlags_addr = process_scan(proc, &ptrn_m_fFlags, srv, srv_size);
    return process_read(proc, m_fFlags_addr + 10, (u8 *)out, 4);
}

// Call to SendPropDataTable pushes a bunch of arguments to stack, one of them
// being the "m_Local" string
static const struct byte_pattern ptrn_m_Local = {
    _PTRN_ARRAY(0x68, 0x00, 0x00, 0x00, 0x00, 0x68, 0x00, 0x00, 0x00, 0x00,
                0x68, 0x00, 0x00, 0x00, 0x00, 0x68, 0x00, 0x00, 0x00, 0x00,
                0x68, 0x00, 0x00, 0x00, 0x00, 0xE8, 0x00, 0x00, 0x00, 0x00,
                0xD9, 0x05, 0x00, 0x00, 0x00, 0x00, 0x83, 0xC4),
    _PTRN_ARRAY(1, 2, 3, 4, 6, 7, 8, 9, 11, 12, 13, 14, 16, 17, 18, 19, 21,
                22, 23, 24, 26, 27, 28, 29, 32, 33, 34, 35)
};
static inline bool find_m_iHideHUD(ProcessId proc, Address server, u64 srv_size,
        int *out) {
    // This pattern may match multiple times, so we validate the match against
    // a string reference
    u64 m_Local, scan_addr = server, scan_sz = srv_size;
    while ((m_Local = process_scan(proc, &ptrn_m_Local, scan_addr, scan_sz))) {
        if (match_string(proc, m_Local + 16, string("m_Local")))
            goto m_Local_found;
        // keep searching
        scan_sz -= (m_Local - scan_addr + ptrn_m_Local.byte_len);
        scan_addr = m_Local + ptrn_m_Local.byte_len;
    }
    return false;
m_Local_found:
    if (!process_read(proc, m_Local + 11, (u8 *)out, 4))
        return false;
    *out += 0x3c; // offset to member inside m_Local never changed
    return true;
}

// CDirector::EndScenario call in CDirector::RestartScenarioFromVote
// 8th byte in EndScenario refers to a member offset into the CDirector object
// for a timer timestamp related to restarting the game
static const struct byte_pattern ptrn_off_restart_game_timer_l4d2 = {
    _PTRN_ARRAY(0xE8, 0x00, 0x00, 0x00, 0x00, 0x83, 0xC4, 0x0C, 0x6A, 0x00,
                0x8B, 0xCE, 0xE8, 0x00, 0x00, 0x00, 0x00, 0x5F),
    _PTRN_ARRAY(1, 2, 3, 4, 13, 14, 15, 16)
};
static inline bool find_off_restart_game_timer_l4d2(ProcessId proc, Address srv,
        u64 srv_size, int *out) {
    // Find call to EndScenario
    Address end_call = process_scan(proc, &ptrn_off_restart_game_timer_l4d2,
            srv, srv_size);
    // Compute EndScenario address via offset on CALL instruction
    int off_EndScenario;
    if (!process_read(proc, end_call + 13, (u8 *)&off_EndScenario, 4))
        return false;
    Address addr_EndScenario = end_call + 17 + off_EndScenario;
    // Read object member offset on the 8th byte
    return process_read(proc, addr_EndScenario + 7, (u8 *)out, 4);
}
// L4D1's Director::EndScenario is inlined in Director::RestartScenarioFromVote
// but the structure is about the same. This pattern points straight to
// EndScenario
static const struct byte_pattern ptrn_off_restart_game_timer_l4d1 = {
    _PTRN_ARRAY(0x83, 0xC4, 0x0C, 0xD9, 0xEE, 0xD8, 0x96, 0x00, 0x00, 0x00,
                0x00),
    _PTRN_ARRAY(7, 8, 9, 10)
};
static inline bool find_off_restart_game_timer_l4d1(ProcessId proc, Address srv,
        u64 srv_size, int *out) {
    Address tmp = process_scan(proc, &ptrn_off_restart_game_timer_l4d1,
            srv, srv_size);
    return process_read(proc, tmp + 7, (u8 *)out, 4);
}

// CRestartGameIssue::ExecuteCommand reads from TheDirector
// (global CDirector* variable)
static const struct byte_pattern ptrn_TheDirector = {
    _PTRN_ARRAY(0x8B, 0x0D, 0x00, 0x00, 0x00, 0x00, 0x56, 0xE8, 0x00, 0x00,
                0x00, 0x00, 0x5E, 0xC3),
    _PTRN_ARRAY(2, 3, 4, 5, 8, 9, 10, 11)
};
static inline bool find_TheDirector(ProcessId proc, Address srv, u64 srv_size,
        Address *out) {
    // TheDirector is initted/teared down on server.dll Init/Shutdown
    // Can't read the global immediately because it's not always filled in
    Address director = process_scan(proc, &ptrn_TheDirector, srv, srv_size);
    return process_read_addr(proc, director + 2, out);
}

// many functions call some virtual function on CMatchExtL4D after setting a
// value on the "Game/chapter" key on a KV object
static const struct byte_pattern ptrn_match_ext = {
    _PTRN_ARRAY(0x68, 0x00, 0x00, 0x00, 0x00, 0x8b, 0xce, 0xe8, 0x00, 0x00,
                0x00, 0x00, 0x8b, 0x0d, 0x00, 0x00, 0x00, 0x00, 0x8b, 0x11,
                0x8b, 0x42),
    _PTRN_ARRAY(1, 2, 3, 4, 8, 9, 10, 11, 14, 15, 16, 17)
};
static inline bool find_kv_mission_metadata(ProcessId gamepid, Address server,
        u64 srv_size, Address *out) {
    // Another pattern with multiple potential matches
    Address tmp, scan_addr = server, scan_sz = srv_size;
    while((tmp = process_scan(gamepid, &ptrn_match_ext, scan_addr, scan_sz))) {
        if (match_string(gamepid, tmp + 1, string("Game/chapter")))
            goto match_ext_found;
        // keep searching
        scan_sz -= (tmp - scan_addr + ptrn_match_ext.byte_len);
        scan_addr = tmp + ptrn_match_ext.byte_len;
    }
    return false;
match_ext_found:
    // Seems to be safe to read this pointer immediately
    if (!process_read_addr(gamepid, tmp + 14, &tmp))
        return false;
    if (!process_read_addr(gamepid, tmp, out))
        return false;
    *out += 4;
    return true;
}
// L4D 1.0 uses a simpler structure to keep track of the available campaigns
// It's directly accessed in CRestartGameIssue::ExecuteCommand
static const struct byte_pattern ptrn_g_ChapterItems = {
    _PTRN_ARRAY(0xB9, 0x00, 0x00, 0x00, 0x00, 0x33, 0xD2, 0x85, 0xC9),
    _PTRN_ARRAY(1, 2, 3, 4)
};
static inline bool find_g_ChapterItems(ProcessId gamepid, Address server,
        u64 srv_size, void *out, int out_size) {
    Address tmp = process_scan(gamepid, &ptrn_g_ChapterItems, server, srv_size);
    if (!process_read_addr(gamepid, tmp + 1, &tmp)) return false;
    return process_read(gamepid, tmp, (u8 *)out, out_size);
}

// Some non-virtual function in CTransitionStatsPanel calls
// SetOverridePostProcessingDisable which sets s_bOverridePostProcessingDisable
// Apparently only the scoreboard interacts with this boolean in the L4D branch
static const struct byte_pattern ptrn_scoreboard_visible = {
    _PTRN_ARRAY(0x56, 0x53, 0x88, 0x99)
};
static inline bool find_scoreboard_visible(ProcessId gamepid, Address client,
        u64 cli_size, Address *out) {
    // Find a call to SetOverridePostProcessingDisable
    Address ovr_pp_call = process_scan(gamepid, &ptrn_scoreboard_visible,
            client, cli_size);
    int off_ovr_pp_disable;
    if (!process_read(gamepid, ovr_pp_call + 9, (u8 *)&off_ovr_pp_disable, 4))
        return false;
    Address ovr_pp_disable_func = ovr_pp_call + 13 + off_ovr_pp_disable;
    // Search for the MOV instruction that sets the global we are interested in
    // No other instruction can have an 0xA2 byte before it
    u8 func_bytes[16];
    if (!process_read(gamepid, ovr_pp_disable_func, func_bytes, 16))
        return false;
    for (int i = 0; i < 16; i++) {
        if (func_bytes[i] == 0xA2) {
            memcpy(out, &func_bytes[i+1], sizeof(Address));
            return true;
        }
    }
    return false;
}

// some random function that calls from an address containing the address of
// KeyValueSystem(), which returns a pointer to an object
static const struct byte_pattern ptrn_KeyValuesSystem = {
    _PTRN_ARRAY(0x56, 0x8B, 0xF1, 0x85, 0xF6, 0x74, 0x00, 0xFF, 0x15),
    _PTRN_ARRAY(6)
};
static inline bool find_kvs_strings(ProcessId gamepid, Address client,
        u64 cli_size, Address *out) {
    // Long chain of dereferencing here
    // Find CALL instruction
    Address tmp = process_scan(gamepid, &ptrn_KeyValuesSystem, client, cli_size);
    // CALL instruction -> pointer to KeyValuesSystem() function
    if (!process_read_addr(gamepid, tmp + 9, &tmp))
        return false;
    // pointer to KeyValuesSystem() function -> address of KeyValuesSystem())
    if (!process_read_addr(gamepid, tmp, &tmp))
        return false;
    // address of KeyValuesSystem() -> address of CKeyValuesSystem object
    if (!process_read_addr(gamepid, tmp + 1, &tmp))
        return false;
    // address of CKeyValuesSystem object -> address of m_Strings.Base()
    return process_read_addr(gamepid, tmp + 0x14, out);
}
