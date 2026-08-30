#define UNICODE
#define _UNICODE
#include <windows.h>
#include <stdio.h>
#include <wchar.h>

static int file_exists(const wchar_t *path) {
    DWORD attrs = GetFileAttributesW(path);
    return attrs != INVALID_FILE_ATTRIBUTES && !(attrs & FILE_ATTRIBUTE_DIRECTORY);
}

static void dirname_inplace(wchar_t *path) {
    wchar_t *slash = wcsrchr(path, L'\\');
    if (slash) *slash = L'\0';
}

static int run_child(const wchar_t *workdir, wchar_t *cmdline) {
    STARTUPINFOW si;
    PROCESS_INFORMATION pi;
    ZeroMemory(&si, sizeof(si));
    ZeroMemory(&pi, sizeof(pi));
    si.cb = sizeof(si);

    if (!CreateProcessW(NULL, cmdline, NULL, NULL, TRUE, 0, NULL, workdir, &si, &pi)) {
        fwprintf(stderr, L"CreateProcess failed: %lu\n", GetLastError());
        return 1;
    }

    WaitForSingleObject(pi.hProcess, INFINITE);
    DWORD exit_code = 1;
    GetExitCodeProcess(pi.hProcess, &exit_code);
    CloseHandle(pi.hThread);
    CloseHandle(pi.hProcess);
    return (int)exit_code;
}

int wmain(int argc, wchar_t **argv) {
    SetConsoleOutputCP(CP_UTF8);

    wchar_t exe_path[MAX_PATH];
    if (!GetModuleFileNameW(NULL, exe_path, MAX_PATH)) {
        fwprintf(stderr, L"Unable to locate launcher path.\n");
        return 1;
    }
    dirname_inplace(exe_path);

    wchar_t qemu[MAX_PATH];
    wchar_t bootkc[MAX_PATH];
    wchar_t dtree[MAX_PATH];
    wchar_t tc[MAX_PATH];
    wchar_t ramdisk[MAX_PATH];
    wchar_t sptm[MAX_PATH];
    wchar_t txm[MAX_PATH];

    swprintf(qemu, MAX_PATH, L"%ls\\qemu-system-aarch64.exe", exe_path);
    swprintf(bootkc, MAX_PATH, L"%ls\\firmware\\bootkc", exe_path);
    swprintf(dtree, MAX_PATH, L"%ls\\firmware\\dtree", exe_path);
    swprintf(tc, MAX_PATH, L"%ls\\firmware\\ramdisk.tc", exe_path);
    swprintf(ramdisk, MAX_PATH, L"%ls\\firmware\\ramdisk.dmg", exe_path);
    swprintf(sptm, MAX_PATH, L"%ls\\firmware\\sptm", exe_path);
    swprintf(txm, MAX_PATH, L"%ls\\firmware\\txm", exe_path);

    if (!file_exists(qemu)) {
        fwprintf(stderr, L"Missing qemu-system-aarch64.exe next to launcher.\n");
        return 2;
    }

    if (argc > 1 && wcscmp(argv[1], L"--self-test") == 0) {
        wchar_t testcmd[32768];
        swprintf(testcmd, 32768, L"\"%ls\" --version", qemu);
        return run_child(exe_path, testcmd);
    }

    const wchar_t *required_names[] = { L"bootkc", L"dtree", L"ramdisk.tc", L"ramdisk.dmg" };
    const wchar_t *required_paths[] = { bootkc, dtree, tc, ramdisk };
    for (int i = 0; i < 4; i++) {
        if (!file_exists(required_paths[i])) {
            fwprintf(stderr, L"Missing firmware\\%ls\n", required_names[i]);
            return 3;
        }
    }

    wchar_t cmd[32768];
    int n = swprintf(
        cmd, 32768,
        L"\"%ls\" -M darwin -bootkc \"%ls\" -dtree \"%ls\" -tc \"%ls\" -ramdisk \"%ls\" "
        L"-args \"rd=md0 serial=3 -v -noprogress wdt=-1 wlan-olyhal-abort\" -nographic -serial mon:stdio -m 8G",
        qemu, bootkc, dtree, tc, ramdisk
    );
    if (n < 0 || n >= 32768) {
        fwprintf(stderr, L"Command line too long.\n");
        return 4;
    }

    if (file_exists(sptm) && file_exists(txm)) {
        size_t used = wcslen(cmd);
        swprintf(cmd + used, 32768 - used, L" -sptm \"%ls\" -txm \"%ls\"", sptm, txm);
    }

    wprintf(L"Starting Darwin VM...\n");
    wprintf(L"Close QEMU with Ctrl+A then X.\n\n");
    return run_child(exe_path, cmd);
}
