#ifndef UNICODE
#define UNICODE
#endif
#ifndef _UNICODE
#define _UNICODE
#endif

#include <windows.h>
#include <windowsx.h>
#include <shellapi.h>
#include <commctrl.h>
#include <string>
#include <vector>
#include <set>
#include <cstring>
#include "resource.h"

#pragma comment(linker, "/subsystem:windows /entry:WinMainCRTStartup")
#pragma comment(lib, "shell32.lib")
#pragma comment(lib, "comctl32.lib")
#pragma comment(lib, "advapi32.lib")

#define WM_TRAYICON (WM_USER + 1)
#define WM_AUTO_LIST_CHANGED (WM_USER + 2)
#define WM_SAVE_SETTINGS_DEFERRED (WM_USER + 3)
#define ID_TRAY_EXIT 1001
#define ID_TRAY_AUTOSTART 1002
#define ID_TRAY_SETRATE 1003
#define ID_TRAY_SETKEYS 1004
#define ID_TRAY_ADVANCED 1005
#define ID_TRAY_TEST 1006

// 频率菜单ID从3000开始
#define ID_TRAY_RATE1 3000
#define ID_TRAY_RATE5 3001
#define ID_TRAY_RATE10 3002
#define ID_TRAY_RATE20 3003
#define ID_TRAY_RATE_CUSTOM 3004

// 高级设置窗口控件ID
#define ID_ADV_CLEAR_BTN 2001
#define ID_ADV_OK_BTN 2002
#define ID_ADV_RADIO_MANUAL 2010
#define ID_ADV_RADIO_AUTO 2011

enum class FilterMode : int {
    QuickAll = 0,
    Advanced = 1,
    AutoLearn = 2
};

static constexpr int kAutoAnomalyToAdd = 5;
static constexpr int kAutoCleanStreakToRemove = 120;
static constexpr int kAutoAnomalyDecayEvery = 20;
// 学习用：只认硬件接触抖动量级，绝不用防抖间隔（否则快打≈全盘）
static constexpr int kLearnBounceMs = 35;
static constexpr int kVkCount = 256;

struct KeyRect {
    int x, y, width, height;
    int keyCode;
    std::wstring name;
};

struct KeyInfo {
    ULONGLONG lastPressMs = 0;
    bool isBlocked = false;
};

struct AutoKeyStats {
    ULONGLONG rawLastMs = 0;
    ULONGLONG downStartedMs = 0;
    bool hasRaw = false;
    bool isDown = false;
    int anomalyHits = 0;
    int cleanStreak = 0;
};

#ifndef WM_ADV_REFRESH_KEYS
#define WM_ADV_REFRESH_KEYS (WM_USER + 20)
#endif

class AdvancedSettingsDialog {
private:
    static std::set<int>* s_selectedKeys;
    static std::set<int>* s_autoKeys;
    static AutoKeyStats* s_autoStats;   // [kVkCount]
    static KeyInfo* s_filterStates;    // [kVkCount]
    static bool* s_autoMask;           // [kVkCount]
    static std::set<int> s_tempKeys;
    static std::vector<KeyRect> s_keyLayouts;
    static HWND s_hwndDialog;
    static HWND s_hwndRadioManual;
    static HWND s_hwndRadioAuto;
    static HWND s_hwndClearBtn;
    static HWND s_hwndOkBtn;
    static HWND s_hwndHint;
    static HWND s_hwndStatus;
    static bool s_dialogResult;
    static bool s_useAutoPage;
    static bool s_resultUseAuto;
    static int s_pressRate;
    static WNDPROC s_oldButtonProc;

    static LRESULT CALLBACK NoKeyButtonProc(HWND hwnd, UINT uMsg, WPARAM wParam, LPARAM lParam) {
        // 按钮不响应空格/回车，避免与「清空」等误绑定
        if (uMsg == WM_KEYDOWN || uMsg == WM_KEYUP || uMsg == WM_CHAR ||
            uMsg == WM_SYSKEYDOWN || uMsg == WM_SYSKEYUP) {
            return 0;
        }
        return CallWindowProcW(s_oldButtonProc, hwnd, uMsg, wParam, lParam);
    }

    static void DisableButtonKeys(HWND btn) {
        if (!btn) return;
        WNDPROC prev = (WNDPROC)SetWindowLongPtrW(btn, GWLP_WNDPROC, (LONG_PTR)NoKeyButtonProc);
        if (!s_oldButtonProc) {
            s_oldButtonProc = prev;
        }
    }

    static void FinishDialog(bool accepted) {
        s_dialogResult = accepted;
        if (accepted) {
            s_resultUseAuto = s_useAutoPage;
            if (!s_useAutoPage && s_selectedKeys) {
                *s_selectedKeys = s_tempKeys;
            }
        }
        if (s_hwndDialog) {
            DestroyWindow(s_hwndDialog);
            s_hwndDialog = nullptr;
        }
    }

    static std::set<int>& EditableKeys() {
        if (s_useAutoPage && s_autoKeys) {
            return *s_autoKeys;
        }
        return s_tempKeys;
    }

public:
    AdvancedSettingsDialog() {}

    static unsigned s_lastStatusCount;
    static HBRUSH s_bgBrush;

    static void InvalidateKeyboardBoard() {
        if (!s_hwndDialog) return;
        RECT board = { 16, 110, 1120, 548 };
        InvalidateRect(s_hwndDialog, &board, FALSE);
    }

    static void UpdateHintAndStatus(bool refreshHint = false, bool forceKeys = false) {
        if (refreshHint && s_hwndHint) {
            const wchar_t* hint = s_useAutoPage
                ? L"自动分析：只把极短接触抖动（约 ≤35ms）计入，正常快打不会纳入。"
                  L"可用鼠标点选/取消任意键。仅鼠标操作。"
                : L"手动选键：用鼠标点选要防抖的键，再次点击可取消。仅鼠标操作。";
            SetWindowTextW(s_hwndHint, hint);
        }
        if (s_hwndStatus) {
            wchar_t buf[192];
            const unsigned n = static_cast<unsigned>(EditableKeys().size());
            if (s_useAutoPage) {
                swprintf_s(buf, L"当前 %u 个按键 · 可点选增减 · 仅 ≤%dms 抖动计入 · ≥%d 次纳入",
                           n, kLearnBounceMs, kAutoAnomalyToAdd);
            } else {
                swprintf_s(buf, L"已选择 %u 个按键 · 点确定后启用高级模式", n);
            }
            if (forceKeys || n != s_lastStatusCount) {
                s_lastStatusCount = n;
                SetWindowTextW(s_hwndStatus, buf);
                InvalidateKeyboardBoard();
            }
        }
    }

    static void OnAutoKeysChanged() {
        if (s_hwndDialog && s_useAutoPage) {
            PostMessage(s_hwndDialog, WM_ADV_REFRESH_KEYS, 0, 0);
        }
    }

    static void SetPageMode(bool useAuto) {
        if (!s_useAutoPage && useAuto && s_selectedKeys) {
            *s_selectedKeys = s_tempKeys;
        }
        s_useAutoPage = useAuto;
        s_lastStatusCount = UINT_MAX;
        if (s_hwndRadioManual) {
            SendMessage(s_hwndRadioManual, BM_SETCHECK, useAuto ? BST_UNCHECKED : BST_CHECKED, 0);
        }
        if (s_hwndRadioAuto) {
            SendMessage(s_hwndRadioAuto, BM_SETCHECK, useAuto ? BST_CHECKED : BST_UNCHECKED, 0);
        }
        UpdateHintAndStatus(true, true);
    }

    static void ToggleKey(int keyCode) {
        if (keyCode == 0) return;
        std::set<int>& keys = EditableKeys();
        if (keys.count(keyCode)) {
            keys.erase(keyCode);
            if (s_useAutoPage) {
                if (s_autoMask && keyCode >= 0 && keyCode < kVkCount) {
                    s_autoMask[keyCode] = false;
                }
                if (s_autoStats && keyCode >= 0 && keyCode < kVkCount) {
                    s_autoStats[keyCode] = AutoKeyStats{};
                }
                if (s_filterStates && keyCode >= 0 && keyCode < kVkCount) {
                    s_filterStates[keyCode] = KeyInfo{};
                }
            }
        } else {
            keys.insert(keyCode);
            if (s_useAutoPage && s_autoMask && keyCode >= 0 && keyCode < kVkCount) {
                s_autoMask[keyCode] = true;
            }
        }
        s_lastStatusCount = UINT_MAX;
        UpdateHintAndStatus(false, true);
    }

    static void ClearCurrentKeys() {
        if (s_useAutoPage) {
            if (s_autoKeys) s_autoKeys->clear();
            if (s_autoMask) ZeroMemory(s_autoMask, sizeof(bool) * kVkCount);
            if (s_autoStats) ZeroMemory(s_autoStats, sizeof(AutoKeyStats) * kVkCount);
            if (s_filterStates) ZeroMemory(s_filterStates, sizeof(KeyInfo) * kVkCount);
        } else {
            s_tempKeys.clear();
        }
        s_lastStatusCount = UINT_MAX;
        UpdateHintAndStatus(false, true);
    }

    static void AddKey(int x, int y, int w, int h, int keyCode, const wchar_t* name) {
        s_keyLayouts.push_back({x, y, w, h, keyCode, name});
    }

    void InitializeKeyLayouts() {
        s_keyLayouts.clear();

        // 完整 ANSI 布局（单位约 46px，含间隙）
        const int U = 46;
        const int G = 5;
        const int OX = 24;   // 主键盘原点 X
        const int OY = 108;  // 主键盘原点 Y

        auto X = [&](double units) { return OX + static_cast<int>(units * (U + G)); };
        auto W = [&](double units) { return static_cast<int>(units * U + (units - 1.0) * G); };

        // --- 功能行 ---
        AddKey(X(0), OY, W(1), U, VK_ESCAPE, L"Esc");
        AddKey(X(2), OY, W(1), U, VK_F1, L"F1");
        AddKey(X(3), OY, W(1), U, VK_F2, L"F2");
        AddKey(X(4), OY, W(1), U, VK_F3, L"F3");
        AddKey(X(5), OY, W(1), U, VK_F4, L"F4");
        AddKey(X(6.5), OY, W(1), U, VK_F5, L"F5");
        AddKey(X(7.5), OY, W(1), U, VK_F6, L"F6");
        AddKey(X(8.5), OY, W(1), U, VK_F7, L"F7");
        AddKey(X(9.5), OY, W(1), U, VK_F8, L"F8");
        AddKey(X(11), OY, W(1), U, VK_F9, L"F9");
        AddKey(X(12), OY, W(1), U, VK_F10, L"F10");
        AddKey(X(13), OY, W(1), U, VK_F11, L"F11");
        AddKey(X(14), OY, W(1), U, VK_F12, L"F12");

        // 右侧：PrtSc / ScrLk / Pause
        const int NAV_X = X(15.5);
        AddKey(NAV_X, OY, W(1), U, VK_SNAPSHOT, L"PrtSc");
        AddKey(NAV_X + (U + G), OY, W(1), U, VK_SCROLL, L"ScrLk");
        AddKey(NAV_X + 2 * (U + G), OY, W(1), U, VK_PAUSE, L"Pause");

        const int R1 = OY + U + G + 8;
        const int R2 = R1 + U + G;
        const int R3 = R2 + U + G;
        const int R4 = R3 + U + G;
        const int R5 = R4 + U + G;
        const int R6 = R5 + U + G;

        // --- 数字行：` 1 2 3 4 5 6 7 8 9 0 - = Backspace ---
        AddKey(X(0), R1, W(1), U, VK_OEM_3, L"`");
        AddKey(X(1), R1, W(1), U, '1', L"1");
        AddKey(X(2), R1, W(1), U, '2', L"2");
        AddKey(X(3), R1, W(1), U, '3', L"3");
        AddKey(X(4), R1, W(1), U, '4', L"4");
        AddKey(X(5), R1, W(1), U, '5', L"5");
        AddKey(X(6), R1, W(1), U, '6', L"6");
        AddKey(X(7), R1, W(1), U, '7', L"7");
        AddKey(X(8), R1, W(1), U, '8', L"8");
        AddKey(X(9), R1, W(1), U, '9', L"9");
        AddKey(X(10), R1, W(1), U, '0', L"0");
        AddKey(X(11), R1, W(1), U, VK_OEM_MINUS, L"-");
        AddKey(X(12), R1, W(1), U, VK_OEM_PLUS, L"=");
        AddKey(X(13), R1, W(2), U, VK_BACK, L"Backspace");

        // Insert / Home / PgUp
        AddKey(NAV_X, R1, W(1), U, VK_INSERT, L"Ins");
        AddKey(NAV_X + (U + G), R1, W(1), U, VK_HOME, L"Home");
        AddKey(NAV_X + 2 * (U + G), R1, W(1), U, VK_PRIOR, L"PgUp");

        // --- Tab 行 ---
        AddKey(X(0), R2, W(1.5), U, VK_TAB, L"Tab");
        AddKey(X(1.5), R2, W(1), U, 'Q', L"Q");
        AddKey(X(2.5), R2, W(1), U, 'W', L"W");
        AddKey(X(3.5), R2, W(1), U, 'E', L"E");
        AddKey(X(4.5), R2, W(1), U, 'R', L"R");
        AddKey(X(5.5), R2, W(1), U, 'T', L"T");
        AddKey(X(6.5), R2, W(1), U, 'Y', L"Y");
        AddKey(X(7.5), R2, W(1), U, 'U', L"U");
        AddKey(X(8.5), R2, W(1), U, 'I', L"I");
        AddKey(X(9.5), R2, W(1), U, 'O', L"O");
        AddKey(X(10.5), R2, W(1), U, 'P', L"P");
        AddKey(X(11.5), R2, W(1), U, VK_OEM_4, L"[");
        AddKey(X(12.5), R2, W(1), U, VK_OEM_6, L"]");
        AddKey(X(13.5), R2, W(1.5), U, VK_OEM_5, L"\\");

        AddKey(NAV_X, R2, W(1), U, VK_DELETE, L"Del");
        AddKey(NAV_X + (U + G), R2, W(1), U, VK_END, L"End");
        AddKey(NAV_X + 2 * (U + G), R2, W(1), U, VK_NEXT, L"PgDn");

        // --- Caps 行 ---
        AddKey(X(0), R3, W(1.75), U, VK_CAPITAL, L"Caps");
        AddKey(X(1.75), R3, W(1), U, 'A', L"A");
        AddKey(X(2.75), R3, W(1), U, 'S', L"S");
        AddKey(X(3.75), R3, W(1), U, 'D', L"D");
        AddKey(X(4.75), R3, W(1), U, 'F', L"F");
        AddKey(X(5.75), R3, W(1), U, 'G', L"G");
        AddKey(X(6.75), R3, W(1), U, 'H', L"H");
        AddKey(X(7.75), R3, W(1), U, 'J', L"J");
        AddKey(X(8.75), R3, W(1), U, 'K', L"K");
        AddKey(X(9.75), R3, W(1), U, 'L', L"L");
        AddKey(X(10.75), R3, W(1), U, VK_OEM_1, L";");
        AddKey(X(11.75), R3, W(1), U, VK_OEM_7, L"'");
        AddKey(X(12.75), R3, W(2.25), U, VK_RETURN, L"Enter");

        // --- Shift 行（使用 VK_LSHIFT / VK_RSHIFT，与底层钩子一致）---
        AddKey(X(0), R4, W(2.25), U, VK_LSHIFT, L"Shift");
        AddKey(X(2.25), R4, W(1), U, 'Z', L"Z");
        AddKey(X(3.25), R4, W(1), U, 'X', L"X");
        AddKey(X(4.25), R4, W(1), U, 'C', L"C");
        AddKey(X(5.25), R4, W(1), U, 'V', L"V");
        AddKey(X(6.25), R4, W(1), U, 'B', L"B");
        AddKey(X(7.25), R4, W(1), U, 'N', L"N");
        AddKey(X(8.25), R4, W(1), U, 'M', L"M");
        AddKey(X(9.25), R4, W(1), U, VK_OEM_COMMA, L",");
        AddKey(X(10.25), R4, W(1), U, VK_OEM_PERIOD, L".");
        AddKey(X(11.25), R4, W(1), U, VK_OEM_2, L"/");
        AddKey(X(12.25), R4, W(2.75), U, VK_RSHIFT, L"Shift");

        // 方向键上
        AddKey(NAV_X + (U + G), R4, W(1), U, VK_UP, L"↑");

        // --- 底行 ---
        AddKey(X(0), R5, W(1.25), U, VK_LCONTROL, L"Ctrl");
        AddKey(X(1.25), R5, W(1.25), U, VK_LWIN, L"Win");
        AddKey(X(2.5), R5, W(1.25), U, VK_LMENU, L"Alt");
        AddKey(X(3.75), R5, W(6.25), U, VK_SPACE, L"Space");
        AddKey(X(10), R5, W(1.25), U, VK_RMENU, L"Alt");
        AddKey(X(11.25), R5, W(1.25), U, VK_RWIN, L"Win");
        AddKey(X(12.5), R5, W(1.25), U, VK_APPS, L"Menu");
        AddKey(X(13.75), R5, W(1.25), U, VK_RCONTROL, L"Ctrl");

        AddKey(NAV_X, R5, W(1), U, VK_LEFT, L"←");
        AddKey(NAV_X + (U + G), R5, W(1), U, VK_DOWN, L"↓");
        AddKey(NAV_X + 2 * (U + G), R5, W(1), U, VK_RIGHT, L"→");

        // --- 小键盘 ---
        const int NX = NAV_X + 3 * (U + G) + 16;
        AddKey(NX, R1, W(1), U, VK_NUMLOCK, L"Num");
        AddKey(NX + (U + G), R1, W(1), U, VK_DIVIDE, L"/");
        AddKey(NX + 2 * (U + G), R1, W(1), U, VK_MULTIPLY, L"*");
        AddKey(NX + 3 * (U + G), R1, W(1), U, VK_SUBTRACT, L"-");

        AddKey(NX, R2, W(1), U, VK_NUMPAD7, L"7");
        AddKey(NX + (U + G), R2, W(1), U, VK_NUMPAD8, L"8");
        AddKey(NX + 2 * (U + G), R2, W(1), U, VK_NUMPAD9, L"9");
        AddKey(NX + 3 * (U + G), R2, W(1), U * 2 + G, VK_ADD, L"+");

        AddKey(NX, R3, W(1), U, VK_NUMPAD4, L"4");
        AddKey(NX + (U + G), R3, W(1), U, VK_NUMPAD5, L"5");
        AddKey(NX + 2 * (U + G), R3, W(1), U, VK_NUMPAD6, L"6");

        AddKey(NX, R4, W(1), U, VK_NUMPAD1, L"1");
        AddKey(NX + (U + G), R4, W(1), U, VK_NUMPAD2, L"2");
        AddKey(NX + 2 * (U + G), R4, W(1), U, VK_NUMPAD3, L"3");
        // 小键盘 Enter 与主 Enter 同为 VK_RETURN，用扩展标记区分不便展示；此处用 VK_SEPARATOR 占位不适用。
        // 采用单独高度的 Enter，绑定仍为 VK_RETURN（与主 Enter 同步选中，见 Toggle 时成对处理可选）。
        AddKey(NX + 3 * (U + G), R4, W(1), U * 2 + G, VK_RETURN, L"Ent");

        AddKey(NX, R5, W(2), U, VK_NUMPAD0, L"0");
        AddKey(NX + 2 * (U + G), R5, W(1), U, VK_DECIMAL, L".");

        (void)R6;
    }

    static LRESULT CALLBACK DialogProc(HWND hwnd, UINT uMsg, WPARAM wParam, LPARAM lParam) {
        switch (uMsg) {
            case WM_CREATE: {
                s_hwndDialog = hwnd;

                s_hwndRadioManual = CreateWindowEx(
                    0, L"BUTTON", L"手动选键（只防抖勾选的键）",
                    WS_CHILD | WS_VISIBLE | BS_AUTORADIOBUTTON | WS_GROUP,
                    24, 12, 320, 24,
                    hwnd, (HMENU)ID_ADV_RADIO_MANUAL, GetModuleHandle(nullptr), nullptr
                );
                s_hwndRadioAuto = CreateWindowEx(
                    0, L"BUTTON", L"自动分析（抖动自动纳入，仍可点选取消）",
                    WS_CHILD | WS_VISIBLE | BS_AUTORADIOBUTTON,
                    360, 12, 420, 24,
                    hwnd, (HMENU)ID_ADV_RADIO_AUTO, GetModuleHandle(nullptr), nullptr
                );

                s_hwndHint = CreateWindowEx(
                    0, L"STATIC", L"",
                    WS_CHILD | WS_VISIBLE,
                    24, 40, 1080, 40,
                    hwnd, nullptr, GetModuleHandle(nullptr), nullptr
                );
                s_hwndStatus = CreateWindowEx(
                    0, L"STATIC", L"",
                    WS_CHILD | WS_VISIBLE,
                    24, 82, 900, 22,
                    hwnd, nullptr, GetModuleHandle(nullptr), nullptr
                );

                s_hwndClearBtn = CreateWindowEx(
                    0, L"BUTTON", L"清空全部",
                    WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
                    24, 560, 110, 34,
                    hwnd, (HMENU)ID_ADV_CLEAR_BTN, GetModuleHandle(nullptr), nullptr
                );
                s_hwndOkBtn = CreateWindowEx(
                    0, L"BUTTON", L"确定",
                    WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
                    1020, 560, 90, 34,
                    hwnd, (HMENU)ID_ADV_OK_BTN, GetModuleHandle(nullptr), nullptr
                );

                HFONT hUiFont = CreateFontW(
                    -15, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
                    DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
                    CLEARTYPE_QUALITY, DEFAULT_PITCH | FF_DONTCARE, L"Segoe UI");
                if (!hUiFont) hUiFont = (HFONT)GetStockObject(DEFAULT_GUI_FONT);
                HWND fontTargets[] = {
                    s_hwndRadioManual, s_hwndRadioAuto, s_hwndHint, s_hwndStatus,
                    s_hwndClearBtn, s_hwndOkBtn
                };
                for (HWND t : fontTargets) SendMessage(t, WM_SETFONT, (WPARAM)hUiFont, TRUE);

                DisableButtonKeys(s_hwndClearBtn);
                DisableButtonKeys(s_hwndOkBtn);
                DisableButtonKeys(s_hwndRadioManual);
                DisableButtonKeys(s_hwndRadioAuto);

                // 选键仅鼠标；吞掉窗口按键，避免空格触发按钮
                SetPageMode(s_useAutoPage);
                SetFocus(hwnd);
                RECT rect; GetWindowRect(hwnd, &rect);
                int width = rect.right - rect.left, height = rect.bottom - rect.top;
                SetWindowPos(hwnd, nullptr, (GetSystemMetrics(SM_CXSCREEN) - width) / 2,
                             (GetSystemMetrics(SM_CYSCREEN) - height) / 2, 0, 0, SWP_NOSIZE | SWP_NOZORDER);
                break;
            }
            case WM_ADV_REFRESH_KEYS:
                UpdateHintAndStatus(false, true);
                break;
            case WM_ERASEBKGND:
                return 1;
            case WM_KEYDOWN:
            case WM_SYSKEYDOWN:
            case WM_CHAR:
                // 设置页禁止按键操作（含空格触发按钮）
                return 0;
            case WM_LBUTTONDOWN: {
                POINT pt = { GET_X_LPARAM(lParam), GET_Y_LPARAM(lParam) };
                for (const auto& key : s_keyLayouts) {
                    if (key.keyCode == 0) continue;
                    if (pt.x >= key.x && pt.x < key.x + key.width &&
                        pt.y >= key.y && pt.y < key.y + key.height) {
                        ToggleKey(key.keyCode);
                        break;
                    }
                }
                SetFocus(hwnd);
                break;
            }
            case WM_COMMAND: {
                switch (LOWORD(wParam)) {
                    case ID_ADV_RADIO_MANUAL: SetPageMode(false); break;
                    case ID_ADV_RADIO_AUTO: SetPageMode(true); break;
                    case ID_ADV_CLEAR_BTN:
                        ClearCurrentKeys();
                        SetFocus(hwnd);
                        break;
                    case ID_ADV_OK_BTN: FinishDialog(true); break;
                }
                break;
            }
            case WM_CTLCOLORSTATIC: {
                if (!s_bgBrush) {
                    s_bgBrush = CreateSolidBrush(RGB(241, 245, 249));
                }
                HDC hdcStatic = (HDC)wParam;
                SetBkColor(hdcStatic, RGB(241, 245, 249));
                SetTextColor(hdcStatic, RGB(51, 65, 85));
                return (LRESULT)s_bgBrush;
            }
            case WM_PAINT: {
                PAINTSTRUCT ps;
                HDC hdc = BeginPaint(hwnd, &ps);
                RECT clientRect; GetClientRect(hwnd, &clientRect);
                HDC memDC = CreateCompatibleDC(hdc);
                HBITMAP memBmp = CreateCompatibleBitmap(hdc, clientRect.right, clientRect.bottom);
                HGDIOBJ oldBmp = SelectObject(memDC, memBmp);
                HBRUSH bgBrush = CreateSolidBrush(RGB(241, 245, 249));
                FillRect(memDC, &clientRect, bgBrush);
                DeleteObject(bgBrush);
                RECT board = { 16, 110, clientRect.right - 16, 548 };
                HBRUSH boardBrush = CreateSolidBrush(RGB(226, 232, 240));
                HPEN boardPen = CreatePen(PS_SOLID, 1, RGB(148, 163, 184));
                HGDIOBJ oldBoardPen = SelectObject(memDC, boardPen);
                HGDIOBJ oldBoardBrush = SelectObject(memDC, boardBrush);
                RoundRect(memDC, board.left, board.top, board.right, board.bottom, 16, 16);
                SelectObject(memDC, oldBoardPen);
                SelectObject(memDC, oldBoardBrush);
                DeleteObject(boardPen);
                DeleteObject(boardBrush);
                HBRUSH selectedBrush = CreateSolidBrush(RGB(37, 99, 235));
                HBRUSH normalBrush = CreateSolidBrush(RGB(255, 255, 255));
                HPEN keyPen = CreatePen(PS_SOLID, 1, RGB(100, 116, 139));
                HGDIOBJ oldPen = SelectObject(memDC, keyPen);
                HFONT keyFont = CreateFontW(-13, 0, 0, 0, FW_SEMIBOLD, FALSE, FALSE, FALSE,
                    DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
                    CLEARTYPE_QUALITY, DEFAULT_PITCH | FF_DONTCARE, L"Segoe UI");
                HGDIOBJ oldFont = SelectObject(memDC, keyFont);
                SetBkMode(memDC, TRANSPARENT);
                const std::set<int>& shown = EditableKeys();
                for (const auto& key : s_keyLayouts) {
                    if (key.keyCode == 0) continue;
                    RECT rect = { key.x, key.y, key.x + key.width, key.y + key.height };
                    const bool selected = shown.count(key.keyCode) > 0;
                    HGDIOBJ oldBrush = SelectObject(memDC, selected ? selectedBrush : normalBrush);
                    RoundRect(memDC, rect.left, rect.top, rect.right, rect.bottom, 8, 8);
                    SelectObject(memDC, oldBrush);
                    SetTextColor(memDC, selected ? RGB(255, 255, 255) : RGB(30, 41, 59));
                    DrawTextW(memDC, key.name.c_str(), -1, &rect, DT_CENTER | DT_VCENTER | DT_SINGLELINE | DT_NOPREFIX);
                }
                SelectObject(memDC, oldFont);
                SelectObject(memDC, oldPen);
                DeleteObject(keyFont);
                DeleteObject(selectedBrush);
                DeleteObject(normalBrush);
                DeleteObject(keyPen);
                BitBlt(hdc, 0, 0, clientRect.right, clientRect.bottom, memDC, 0, 0, SRCCOPY);
                SelectObject(memDC, oldBmp);
                DeleteObject(memBmp);
                DeleteDC(memDC);
                EndPaint(hwnd, &ps);
                break;
            }
            case WM_CLOSE:
                // 无「取消」：关窗口即确认当前选择
                FinishDialog(true);
                break;
            case WM_DESTROY:
                PostQuitMessage(0);
                break;
        }
        return DefWindowProc(hwnd, uMsg, wParam, lParam);
    }

    bool ShowDialog(HWND parentHwnd, std::set<int>& keys, bool& useAutoLearn,
                    std::set<int>& autoKeys, AutoKeyStats* autoStatsArr, KeyInfo* filterStatesArr,
                    bool* autoMaskArr, int pressRate) {
        s_selectedKeys = &keys;
        s_autoKeys = &autoKeys;
        s_autoStats = autoStatsArr;
        s_filterStates = filterStatesArr;
        s_autoMask = autoMaskArr;
        s_pressRate = pressRate;
        s_useAutoPage = useAutoLearn;
        s_resultUseAuto = useAutoLearn;
        s_dialogResult = false;

        s_tempKeys.clear();
        for (int keyCode : keys) {
            int migrated = keyCode;
            if (migrated == VK_SHIFT) migrated = VK_LSHIFT;
            else if (migrated == VK_CONTROL) migrated = VK_LCONTROL;
            else if (migrated == VK_MENU) migrated = VK_LMENU;
            s_tempKeys.insert(migrated);
        }
        InitializeKeyLayouts();

        WNDCLASSEX wc = {};
        wc.cbSize = sizeof(WNDCLASSEX);
        if (!GetClassInfoExW(GetModuleHandle(nullptr), L"AdvancedKeyboardDialog", &wc)) {
            wc = {};
            wc.cbSize = sizeof(WNDCLASSEX);
            wc.lpfnWndProc = DialogProc;
            wc.hInstance = GetModuleHandle(nullptr);
            wc.lpszClassName = L"AdvancedKeyboardDialog";
            wc.hbrBackground = nullptr;
            HICON hIcon = LoadIcon(GetModuleHandle(nullptr), MAKEINTRESOURCE(IDI_MAIN_ICON));
            if (!hIcon) hIcon = (HICON)LoadImageW(nullptr, L"keyboard_icon.ico", IMAGE_ICON, 32, 32, LR_LOADFROMFILE);
            if (!hIcon) hIcon = LoadIcon(nullptr, IDI_APPLICATION);
            wc.hIcon = hIcon;
            wc.hCursor = LoadCursor(nullptr, IDC_ARROW);
            if (!RegisterClassEx(&wc)) return false;
        }

        s_hwndDialog = CreateWindowEx(
            WS_EX_DLGMODALFRAME | WS_EX_TOPMOST,
            L"AdvancedKeyboardDialog", L"高级设置",
            WS_POPUP | WS_CAPTION | WS_SYSMENU,
            0, 0, 1140, 650, parentHwnd, nullptr, GetModuleHandle(nullptr), nullptr);
        if (!s_hwndDialog) return false;
        ShowWindow(s_hwndDialog, SW_SHOW);
        UpdateWindow(s_hwndDialog);
        MSG msg;
        while (GetMessage(&msg, nullptr, 0, 0)) {
            TranslateMessage(&msg);
            DispatchMessage(&msg);
        }
        if (s_dialogResult) useAutoLearn = s_resultUseAuto;
        return s_dialogResult;
    }
};

std::set<int>* AdvancedSettingsDialog::s_selectedKeys = nullptr;
std::set<int>* AdvancedSettingsDialog::s_autoKeys = nullptr;
AutoKeyStats* AdvancedSettingsDialog::s_autoStats = nullptr;
KeyInfo* AdvancedSettingsDialog::s_filterStates = nullptr;
bool* AdvancedSettingsDialog::s_autoMask = nullptr;
std::set<int> AdvancedSettingsDialog::s_tempKeys;
std::vector<KeyRect> AdvancedSettingsDialog::s_keyLayouts;
HWND AdvancedSettingsDialog::s_hwndDialog = nullptr;
HWND AdvancedSettingsDialog::s_hwndRadioManual = nullptr;
HWND AdvancedSettingsDialog::s_hwndRadioAuto = nullptr;
HWND AdvancedSettingsDialog::s_hwndClearBtn = nullptr;
HWND AdvancedSettingsDialog::s_hwndOkBtn = nullptr;
HWND AdvancedSettingsDialog::s_hwndHint = nullptr;
HWND AdvancedSettingsDialog::s_hwndStatus = nullptr;
bool AdvancedSettingsDialog::s_dialogResult = false;
bool AdvancedSettingsDialog::s_useAutoPage = false;
bool AdvancedSettingsDialog::s_resultUseAuto = false;
int AdvancedSettingsDialog::s_pressRate = 10;
WNDPROC AdvancedSettingsDialog::s_oldButtonProc = nullptr;
unsigned AdvancedSettingsDialog::s_lastStatusCount = UINT_MAX;
HBRUSH AdvancedSettingsDialog::s_bgBrush = nullptr;

class KeyboardFilter {
private:
    static KeyboardFilter* s_instance;
    HHOOK keyboardHook;
    NOTIFYICONDATA nid;
    HMENU hMenu;
    HMENU hKeyMenu;
    HMENU hRateMenu;
    HWND hwnd;
    bool autoStart;
    int pressRate;
    FilterMode mode;
    std::set<int> targetKeys;
    std::set<int> autoKeys;
    bool targetMask[kVkCount];
    bool autoMask[kVkCount];
    KeyInfo keyStates[kVkCount];
    AutoKeyStats autoStats[kVkCount];
    AdvancedSettingsDialog advancedDialog;
    int cachedMinIntervalMs;
    bool settingsDirty;
    bool savePosted;

    static int ClampPressRate(int rate) {
        if (rate < 1) return 1;
        if (rate > 50) return 50;
        return rate;
    }

    void RefreshTimingCache() {
        cachedMinIntervalMs = 1000 / ClampPressRate(pressRate);
    }

    void SyncMasks() {
        ZeroMemory(targetMask, sizeof(targetMask));
        ZeroMemory(autoMask, sizeof(autoMask));
        for (int keyCode : targetKeys) {
            if (keyCode >= 0 && keyCode < kVkCount) {
                targetMask[keyCode] = true;
            }
        }
        for (int keyCode : autoKeys) {
            if (keyCode >= 0 && keyCode < kVkCount) {
                autoMask[keyCode] = true;
            }
        }
    }

    void RequestDeferredSave() {
        settingsDirty = true;
        if (!savePosted && hwnd) {
            savePosted = true;
            PostMessage(hwnd, WM_SAVE_SETTINGS_DEFERRED, 0, 0);
        }
    }

    int MinIntervalMs() const {
        return cachedMinIntervalMs;
    }

    void DestroyMenus() {
        if (hMenu) {
            DestroyMenu(hMenu);
        }
        hMenu = nullptr;
        hKeyMenu = nullptr;
        hRateMenu = nullptr;
    }

    static int MigrateLegacyVk(int vk) {
        if (vk == VK_SHIFT) return VK_LSHIFT;
        if (vk == VK_CONTROL) return VK_LCONTROL;
        if (vk == VK_MENU) return VK_LMENU;
        return vk;
    }

    void LoadKeyList(HKEY hKey, const wchar_t* countName, const wchar_t* itemPrefix, std::set<int>& outKeys) {
        outKeys.clear();
        DWORD keyCount = 0;
        DWORD size = sizeof(keyCount);
        if (RegQueryValueEx(hKey, countName, nullptr, nullptr, (LPBYTE)&keyCount, &size) != ERROR_SUCCESS || keyCount == 0) {
            return;
        }
        if (keyCount > 256) {
            keyCount = 256;
        }
        for (DWORD i = 0; i < keyCount; ++i) {
            DWORD value = 0;
            size = sizeof(value);
            std::wstring valueName = std::wstring(itemPrefix) + std::to_wstring(i);
            if (RegQueryValueEx(hKey, valueName.c_str(), nullptr, nullptr, (LPBYTE)&value, &size) == ERROR_SUCCESS) {
                outKeys.insert(MigrateLegacyVk(static_cast<int>(value)));
            }
        }
    }

    void SaveKeyList(HKEY hKey, const wchar_t* countName, const wchar_t* itemPrefix, const std::set<int>& keys) {
        DWORD keyCount = static_cast<DWORD>(keys.size());
        RegSetValueEx(hKey, countName, 0, REG_DWORD, (LPBYTE)&keyCount, sizeof(keyCount));
        int index = 0;
        for (int keyCode : keys) {
            std::wstring valueName = std::wstring(itemPrefix) + std::to_wstring(index);
            RegSetValueEx(hKey, valueName.c_str(), 0, REG_DWORD, (LPBYTE)&keyCode, sizeof(keyCode));
            index++;
        }
    }

    bool ApplyDebounce(int keyCode) {
        if (static_cast<unsigned>(keyCode) >= kVkCount) {
            return false;
        }
        const ULONGLONG now = GetTickCount64();
        KeyInfo& keyInfo = keyStates[keyCode];
        const ULONGLONG elapsed = now - keyInfo.lastPressMs;

        if (keyInfo.isBlocked) {
            if (elapsed < static_cast<ULONGLONG>(cachedMinIntervalMs)) {
                return true;
            }
            keyInfo.isBlocked = false;
        }

        keyInfo.lastPressMs = now;
        keyInfo.isBlocked = true;
        return false;
    }

    // 只分析钩子原始信号。学习窗口与防抖间隔脱钩：只认硬件级极短抖动，避免快打误纳入。
    void AnalyzeRawKeyDown(int keyCode) {
        if (static_cast<unsigned>(keyCode) >= kVkCount) {
            return;
        }

        const ULONGLONG now = GetTickCount64();
        AutoKeyStats& stats = autoStats[keyCode];
        bool listChanged = false;

        auto tryAdd = [&]() {
            if (!autoMask[keyCode] && stats.anomalyHits >= kAutoAnomalyToAdd) {
                autoKeys.insert(keyCode);
                autoMask[keyCode] = true;
                keyStates[keyCode].lastPressMs = now;
                keyStates[keyCode].isBlocked = true;
                listChanged = true;
            }
        };

        auto tryRemove = [&]() {
            if (autoMask[keyCode] && stats.cleanStreak >= kAutoCleanStreakToRemove) {
                autoKeys.erase(keyCode);
                autoMask[keyCode] = false;
                stats.anomalyHits = 0;
                stats.cleanStreak = 0;
                keyStates[keyCode] = KeyInfo{};
                listChanged = true;
            }
        };

        auto noteAnomaly = [&]() {
            stats.anomalyHits++;
            stats.cleanStreak = 0;
            tryAdd();
        };

        auto noteClean = [&]() {
            stats.cleanStreak++;
            if (stats.cleanStreak % kAutoAnomalyDecayEvery == 0 && stats.anomalyHits > 0) {
                stats.anomalyHits--;
            }
            tryRemove();
        };

        // 仍处于按下：后续 KEYDOWN 是连发或按住时的接触抖动
        if (stats.isDown) {
            const ULONGLONG sinceLast = now - stats.rawLastMs;
            // KEYUP 可能丢失；长时间无事件后再来 KEYDOWN，当作新一次按下
            if (sinceLast > 500) {
                stats.isDown = false;
            } else {
                const ULONGLONG sinceDown = now - stats.downStartedMs;
                stats.rawLastMs = now;
                if (sinceDown >= 180) {
                    // 系统自动连发区，完全忽略学习
                    return;
                }
                if (sinceLast < static_cast<ULONGLONG>(kLearnBounceMs)) {
                    // 未抬起时极短重复 down = 接触抖动
                    noteAnomaly();
                }
                // 间隔更大的重复 down：既非明确抖动也非连发，忽略（不误伤快打）
                if (listChanged) {
                    if (hwnd) {
                        PostMessage(hwnd, WM_AUTO_LIST_CHANGED, 0, 0);
                    }
                    AdvancedSettingsDialog::OnAutoKeysChanged();
                }
                return;
            }
        }

        // 新的一次按下（上一击已抬起）
        {
            const ULONGLONG dt = stats.hasRaw ? (now - stats.rawLastMs) : 1000000ULL;
            stats.isDown = true;
            stats.downStartedMs = now;
            stats.rawLastMs = now;
            stats.hasRaw = true;

            if (dt < static_cast<ULONGLONG>(kLearnBounceMs)) {
                // 抬起后极短再次按下 = 硬件回弹；正常快打远大于此窗口
                noteAnomaly();
            } else {
                noteClean();
            }
        }

        if (listChanged) {
            if (hwnd) {
                PostMessage(hwnd, WM_AUTO_LIST_CHANGED, 0, 0);
            }
            AdvancedSettingsDialog::OnAutoKeysChanged();
        }
    }

    void AnalyzeRawKeyUp(int keyCode) {
        if (static_cast<unsigned>(keyCode) >= kVkCount) {
            return;
        }
        AutoKeyStats& stats = autoStats[keyCode];
        stats.isDown = false;
        stats.rawLastMs = GetTickCount64();
    }

public:
    KeyboardFilter()
        : keyboardHook(nullptr), hMenu(nullptr), hKeyMenu(nullptr), hRateMenu(nullptr),
          hwnd(nullptr), autoStart(false), pressRate(10), mode(FilterMode::QuickAll),
          cachedMinIntervalMs(100),
          settingsDirty(false), savePosted(false) {
        s_instance = this;
        ZeroMemory(&nid, sizeof(nid));
        ZeroMemory(targetMask, sizeof(targetMask));
        ZeroMemory(autoMask, sizeof(autoMask));
        ZeroMemory(keyStates, sizeof(keyStates));
        ZeroMemory(autoStats, sizeof(autoStats));
        LoadSettings();
        RefreshTimingCache();
        SyncMasks();
    }

    ~KeyboardFilter() {
        if (keyboardHook) {
            UnhookWindowsHookEx(keyboardHook);
            keyboardHook = nullptr;
        }
        if (nid.hWnd) {
            Shell_NotifyIcon(NIM_DELETE, &nid);
        }
        DestroyMenus();
        if (s_instance == this) {
            s_instance = nullptr;
        }
    }

    void LoadSettings() {
        HKEY hKey;
        if (RegOpenKeyEx(HKEY_CURRENT_USER, L"Software\\KeyboardFilter", 0, KEY_READ, &hKey) != ERROR_SUCCESS) {
            return;
        }

        DWORD value = 0;
        DWORD size = sizeof(value);

        if (RegQueryValueEx(hKey, L"PressRate", nullptr, nullptr, (LPBYTE)&value, &size) == ERROR_SUCCESS) {
            pressRate = ClampPressRate(static_cast<int>(value));
        }

        size = sizeof(value);
        if (RegQueryValueEx(hKey, L"AutoStart", nullptr, nullptr, (LPBYTE)&value, &size) == ERROR_SUCCESS) {
            autoStart = (value != 0);
        }

        bool hasMode = false;
        size = sizeof(value);
        if (RegQueryValueEx(hKey, L"FilterMode", nullptr, nullptr, (LPBYTE)&value, &size) == ERROR_SUCCESS) {
            hasMode = true;
            if (value == static_cast<DWORD>(FilterMode::Advanced)) {
                mode = FilterMode::Advanced;
            } else if (value == static_cast<DWORD>(FilterMode::AutoLearn)) {
                mode = FilterMode::AutoLearn;
            } else {
                mode = FilterMode::QuickAll;
            }
        }

        LoadKeyList(hKey, L"AdvancedKeyCount", L"AdvancedKey", targetKeys);
        LoadKeyList(hKey, L"AutoKeyCount", L"AutoKey", autoKeys);

        // 兼容旧版 AdvancedMode / FilterAllKeys
        if (!hasMode) {
            size = sizeof(value);
            bool advanced = false;
            if (RegQueryValueEx(hKey, L"AdvancedMode", nullptr, nullptr, (LPBYTE)&value, &size) == ERROR_SUCCESS) {
                advanced = (value != 0);
            }
            if (advanced) {
                mode = FilterMode::Advanced;
            } else {
                mode = FilterMode::QuickAll;
            }
        }

        RegCloseKey(hKey);
        RefreshTimingCache();
        SyncMasks();
    }

    void SaveSettings() {
        settingsDirty = false;
        savePosted = false;
        HKEY hKey;
        if (RegCreateKeyEx(HKEY_CURRENT_USER, L"Software\\KeyboardFilter", 0, nullptr,
                          REG_OPTION_NON_VOLATILE, KEY_WRITE, nullptr, &hKey, nullptr) != ERROR_SUCCESS) {
            return;
        }

        DWORD value = pressRate;
        RegSetValueEx(hKey, L"PressRate", 0, REG_DWORD, (LPBYTE)&value, sizeof(value));

        value = autoStart ? 1 : 0;
        RegSetValueEx(hKey, L"AutoStart", 0, REG_DWORD, (LPBYTE)&value, sizeof(value));

        value = static_cast<DWORD>(mode);
        RegSetValueEx(hKey, L"FilterMode", 0, REG_DWORD, (LPBYTE)&value, sizeof(value));

        // 兼容旧字段
        value = (mode == FilterMode::Advanced) ? 1 : 0;
        RegSetValueEx(hKey, L"AdvancedMode", 0, REG_DWORD, (LPBYTE)&value, sizeof(value));
        value = (mode == FilterMode::QuickAll) ? 1 : 0;
        RegSetValueEx(hKey, L"FilterAllKeys", 0, REG_DWORD, (LPBYTE)&value, sizeof(value));

        SaveKeyList(hKey, L"AdvancedKeyCount", L"AdvancedKey", targetKeys);
        SaveKeyList(hKey, L"AutoKeyCount", L"AutoKey", autoKeys);

        RegCloseKey(hKey);
    }

    void SetMode(FilterMode newMode) {
        mode = newMode;
        SaveSettings();
        UpdateTrayIcon();
    }

    void SelectQuickMode() {
        MessageBoxW(nullptr,
            L"已切换到全盘模式。\n\n"
            L"将对【全部按键】按当前频率防抖。\n"
            L"若只需对个别键防抖，或想用自动分析，请打开「高级设置」。",
            L"全盘模式", MB_OK | MB_ICONINFORMATION);
        SetMode(FilterMode::QuickAll);
    }

    LRESULT KeyboardProc(int nCode, WPARAM wParam, LPARAM lParam) {
        if (nCode >= 0) {
            KBDLLHOOKSTRUCT* kbStruct = (KBDLLHOOKSTRUCT*)lParam;
            int keyCode = kbStruct->vkCode;
            if (kbStruct->flags & LLKHF_INJECTED) {
                return CallNextHookEx(keyboardHook, nCode, wParam, lParam);
            }

            if (wParam == WM_KEYUP || wParam == WM_SYSKEYUP) {
                if (mode == FilterMode::AutoLearn) {
                    AnalyzeRawKeyUp(keyCode);
                }
                return CallNextHookEx(keyboardHook, nCode, wParam, lParam);
            }

            if (wParam == WM_KEYDOWN || wParam == WM_SYSKEYDOWN) {
                switch (mode) {
                    case FilterMode::QuickAll:
                        if (ApplyDebounce(keyCode)) return 1;
                        break;
                    case FilterMode::Advanced:
                        if (keyCode >= 0 && keyCode < kVkCount && targetMask[keyCode] && ApplyDebounce(keyCode)) {
                            return 1;
                        }
                        break;
                    case FilterMode::AutoLearn:
                        AnalyzeRawKeyDown(keyCode);
                        if (keyCode >= 0 && keyCode < kVkCount && autoMask[keyCode] && ApplyDebounce(keyCode)) {
                            return 1;
                        }
                        break;
                }
            }
        }
        return CallNextHookEx(keyboardHook, nCode, wParam, lParam);
    }

    static LRESULT CALLBACK StaticKeyboardProc(int nCode, WPARAM wParam, LPARAM lParam) {
        if (s_instance) return s_instance->KeyboardProc(nCode, wParam, lParam);
        return CallNextHookEx(nullptr, nCode, wParam, lParam);
    }

    std::wstring GetStatusText() {
        switch (mode) {
            case FilterMode::QuickAll: return L"全盘";
            case FilterMode::Advanced: return L"手动(" + std::to_wstring(targetKeys.size()) + L")";
            case FilterMode::AutoLearn: return L"自动(" + std::to_wstring(autoKeys.size()) + L")";
        }
        return L"?";
    }

    void TestAntiBounce() {
        switch (mode) {
            case FilterMode::QuickAll:
                MessageBoxW(nullptr, L"防抖测试：\n\n全盘模式：全部按键防抖。\n请快速连按任意键验证。",
                            L"防抖测试", MB_OK | MB_ICONINFORMATION);
                break;
            case FilterMode::Advanced:
                if (targetKeys.empty()) {
                    MessageBoxW(nullptr, L"防抖测试：\n\n手动选键为空。请打开「高级设置」勾选按键。",
                                L"防抖测试", MB_OK | MB_ICONWARNING);
                } else {
                    MessageBoxW(nullptr,
                        (L"防抖测试：\n\n手动模式已选 " + std::to_wstring(targetKeys.size()) + L" 键。").c_str(),
                        L"防抖测试", MB_OK | MB_ICONINFORMATION);
                }
                break;
            case FilterMode::AutoLearn:
                MessageBoxW(nullptr,
                    (L"防抖测试：\n\n自动分析，当前纳入 " + std::to_wstring(autoKeys.size()) +
                     L" 键。\n对可疑键制造抖动；纳入后连按应被过滤。").c_str(),
                    L"防抖测试", MB_OK | MB_ICONINFORMATION);
                break;
        }
    }

    void SetPressRate(int newRate) {
        pressRate = ClampPressRate(newRate);
        RefreshTimingCache();
        SaveSettings();
        UpdateTrayIcon();
    }

    void ShowAdvancedDialog() {
        bool useAuto = (mode == FilterMode::AutoLearn);
        if (advancedDialog.ShowDialog(hwnd, targetKeys, useAuto, autoKeys, autoStats, keyStates, autoMask, pressRate)) {
            mode = useAuto ? FilterMode::AutoLearn : FilterMode::Advanced;
            SyncMasks();
            SaveSettings();
            UpdateTrayIcon();
        }
    }

    void InstallHook() {
        keyboardHook = SetWindowsHookEx(WH_KEYBOARD_LL, StaticKeyboardProc, GetModuleHandle(nullptr), 0);
    }

    void CreateTrayIcon() {
        nid.cbSize = sizeof(NOTIFYICONDATA);
        nid.hWnd = hwnd;
        nid.uID = 1;
        nid.uFlags = NIF_ICON | NIF_MESSAGE | NIF_TIP;
        nid.uCallbackMessage = WM_TRAYICON;

        // 优先从嵌入资源加载，其次从同目录文件加载
        HICON hIcon = LoadIcon(GetModuleHandle(nullptr), MAKEINTRESOURCE(IDI_MAIN_ICON));
        if (!hIcon) {
            hIcon = (HICON)LoadImageW(nullptr, L"keyboard_icon.ico", IMAGE_ICON, 32, 32, LR_LOADFROMFILE);
        }
        if (!hIcon) {
            hIcon = LoadIcon(nullptr, IDI_APPLICATION);
        }
        nid.hIcon = hIcon;

        UpdateTrayIcon();
        Shell_NotifyIcon(NIM_ADD, &nid);
    }

    void UpdateTrayIcon() {
        // 托盘 tip 空间有限，只放短状态；详细说明在设置页
        wchar_t tip[128];
        swprintf_s(tip, L"键盘防抖 · %s · %d/秒", GetStatusText().c_str(), pressRate);
        wcsncpy_s(nid.szTip, tip, _TRUNCATE);
        Shell_NotifyIcon(NIM_MODIFY, &nid);
    }

    void CreateMenus() {
        DestroyMenus();

        hMenu = CreatePopupMenu();
        hKeyMenu = CreatePopupMenu();
        UINT quickFlag = (mode == FilterMode::QuickAll) ? MF_CHECKED : MF_UNCHECKED;
        UINT advFlag = (mode == FilterMode::Advanced || mode == FilterMode::AutoLearn) ? MF_CHECKED : MF_UNCHECKED;

        AppendMenuW(hKeyMenu, MF_STRING | quickFlag, ID_TRAY_SETKEYS, L"全盘模式（全部按键防抖）");
        AppendMenuW(hKeyMenu, MF_STRING | advFlag, ID_TRAY_ADVANCED, L"高级设置（手动选键 / 自动分析）...");
        AppendMenuW(hKeyMenu, MF_SEPARATOR, 0, nullptr);
        AppendMenuW(hKeyMenu, MF_STRING, ID_TRAY_TEST, L"测试防抖效果");

        // 创建频率子菜单
        hRateMenu = CreatePopupMenu();
        AppendMenuW(hRateMenu, MF_STRING, ID_TRAY_RATE1, L"1次/秒 (非常强防抖)");
        AppendMenuW(hRateMenu, MF_STRING, ID_TRAY_RATE5, L"5次/秒 (中等防抖)");
        AppendMenuW(hRateMenu, MF_STRING, ID_TRAY_RATE10, L"10次/秒 (默认防抖)");
        AppendMenuW(hRateMenu, MF_STRING, ID_TRAY_RATE20, L"20次/秒 (轻微防抖)");

        // 标记当前选中的频率
        switch (pressRate) {
            case 1: CheckMenuItem(hRateMenu, ID_TRAY_RATE1, MF_CHECKED); break;
            case 5: CheckMenuItem(hRateMenu, ID_TRAY_RATE5, MF_CHECKED); break;
            case 10: CheckMenuItem(hRateMenu, ID_TRAY_RATE10, MF_CHECKED); break;
            case 20: CheckMenuItem(hRateMenu, ID_TRAY_RATE20, MF_CHECKED); break;
            default:
                break;
        }

        // 添加主菜单项
        std::wstring autostartText = autoStart ? L"关闭自启" : L"开启自启";
        AppendMenuW(hMenu, MF_STRING, ID_TRAY_AUTOSTART, autostartText.c_str());

        AppendMenuW(hMenu, MF_POPUP, (UINT_PTR)hRateMenu, L"更改默认防抖频率");
        AppendMenuW(hMenu, MF_POPUP, (UINT_PTR)hKeyMenu, L"工作模式");

        AppendMenu(hMenu, MF_SEPARATOR, 0, nullptr);
        AppendMenuW(hMenu, MF_STRING, ID_TRAY_EXIT, L"退出");
    }

    void UpdateAutoStart(bool enabled) {
        autoStart = enabled;
        SaveSettings();

        HKEY hKey;
        if (enabled) {
            // 启用自启动（路径加引号，兼容含空格/中文目录）
            wchar_t exePath[MAX_PATH];
            DWORD result = GetModuleFileNameW(nullptr, exePath, MAX_PATH);

            if (result > 0 && result < MAX_PATH) {
                if (RegCreateKeyEx(HKEY_CURRENT_USER, L"Software\\Microsoft\\Windows\\CurrentVersion\\Run",
                                  0, nullptr, REG_OPTION_NON_VOLATILE, KEY_WRITE, nullptr, &hKey, nullptr) == ERROR_SUCCESS) {
                    std::wstring quoted = L"\"";
                    quoted += exePath;
                    quoted += L"\"";
                    LONG setResult = RegSetValueEx(hKey, L"KeyboardFilter", 0, REG_SZ,
                                                   (LPBYTE)quoted.c_str(),
                                                   static_cast<DWORD>((quoted.size() + 1) * sizeof(wchar_t)));
                    RegCloseKey(hKey);

                    if (setResult != ERROR_SUCCESS) {
                        MessageBoxW(nullptr, L"启用自启动失败", L"错误", MB_OK | MB_ICONERROR);
                    }
                }
            }
        } else {
            LONG deleteResult = ERROR_SUCCESS;
            if (RegOpenKeyEx(HKEY_CURRENT_USER, L"Software\\Microsoft\\Windows\\CurrentVersion\\Run", 0, KEY_WRITE, &hKey) == ERROR_SUCCESS) {
                deleteResult = RegDeleteValue(hKey, L"KeyboardFilter");
                RegCloseKey(hKey);
            }
            if (deleteResult != ERROR_SUCCESS && deleteResult != ERROR_FILE_NOT_FOUND) {
                MessageBoxW(nullptr, L"禁用自启动失败", L"错误", MB_OK | MB_ICONERROR);
            }
        }
    }

    void HandleTrayMessage(LPARAM lParam) {
        if (lParam == WM_RBUTTONUP) {
            CreateMenus();

            POINT pt;
            GetCursorPos(&pt);
            SetForegroundWindow(hwnd);
            TrackPopupMenu(hMenu, TPM_RIGHTBUTTON, pt.x, pt.y, 0, hwnd, nullptr);
            PostMessage(hwnd, WM_NULL, 0, 0);
        }
    }

    void Run() {
        WNDCLASSEX wc = {};
        wc.cbSize = sizeof(WNDCLASSEX);
        if (!GetClassInfoExW(GetModuleHandle(nullptr), L"KeyboardFilter", &wc)) {
            wc = {};
            wc.cbSize = sizeof(WNDCLASSEX);
            wc.lpfnWndProc = WindowProc;
            wc.hInstance = GetModuleHandle(nullptr);
            wc.lpszClassName = L"KeyboardFilter";
            HICON hIcon = LoadIcon(GetModuleHandle(nullptr), MAKEINTRESOURCE(IDI_MAIN_ICON));
            if (!hIcon) {
                hIcon = (HICON)LoadImageW(nullptr, L"keyboard_icon.ico", IMAGE_ICON, 32, 32, LR_LOADFROMFILE);
            }
            if (!hIcon) {
                hIcon = LoadIcon(nullptr, IDI_APPLICATION);
            }
            wc.hIcon = hIcon;
            wc.hCursor = LoadCursor(nullptr, IDC_ARROW);
            wc.hbrBackground = (HBRUSH)(COLOR_WINDOW + 1);
            if (!RegisterClassEx(&wc)) {
                MessageBoxW(nullptr, L"注册窗口类失败", L"错误", MB_OK | MB_ICONERROR);
                return;
            }
        }

        hwnd = CreateWindowEx(0, L"KeyboardFilter", L"KeyboardFilter", 0, 0, 0, 0, 0, nullptr, nullptr, GetModuleHandle(nullptr), nullptr);
        if (!hwnd) {
            MessageBoxW(nullptr, L"创建主窗口失败", L"错误", MB_OK | MB_ICONERROR);
            return;
        }

        SetWindowLongPtr(hwnd, GWLP_USERDATA, (LONG_PTR)this);

        InstallHook();
        if (!keyboardHook) {
            MessageBoxW(nullptr, L"无法安装键盘钩子！\n\n请确保有足够的权限，\n或尝试以管理员身份运行程序。", L"错误", MB_OK | MB_ICONERROR);
            return;
        }
        CreateTrayIcon();

        MSG msg;
        while (GetMessage(&msg, nullptr, 0, 0)) {
            TranslateMessage(&msg);
            DispatchMessage(&msg);
        }
    }

    static LRESULT CALLBACK WindowProc(HWND hwnd, UINT uMsg, WPARAM wParam, LPARAM lParam) {
        KeyboardFilter* filter = (KeyboardFilter*)GetWindowLongPtr(hwnd, GWLP_USERDATA);

        switch (uMsg) {
            case WM_TRAYICON:
                if (filter) filter->HandleTrayMessage(lParam);
                break;

            case WM_AUTO_LIST_CHANGED:
                if (filter) {
                    filter->UpdateTrayIcon();
                    filter->RequestDeferredSave();
                }
                break;

            case WM_SAVE_SETTINGS_DEFERRED:
                if (filter && filter->settingsDirty) {
                    filter->SaveSettings();
                } else if (filter) {
                    filter->savePosted = false;
                }
                break;

            case WM_COMMAND:
                if (filter) {
                    int command = LOWORD(wParam);

                    switch (command) {
                        case ID_TRAY_EXIT:
                            filter->SaveSettings();
                            PostQuitMessage(0);
                            break;
                        case ID_TRAY_AUTOSTART:
                            filter->UpdateAutoStart(!filter->autoStart);
                            break;
                        case ID_TRAY_SETKEYS:
                            filter->SelectQuickMode();
                            break;
                        case ID_TRAY_ADVANCED:
                            filter->ShowAdvancedDialog();
                            break;
                        case ID_TRAY_TEST:
                            filter->TestAntiBounce();
                            break;
                    }

                    // 频率菜单命令
                    if (command >= ID_TRAY_RATE1 && command <= ID_TRAY_RATE20) {
                        switch (command) {
                            case ID_TRAY_RATE1: filter->SetPressRate(1); break;
                            case ID_TRAY_RATE5: filter->SetPressRate(5); break;
                            case ID_TRAY_RATE10: filter->SetPressRate(10); break;
                            case ID_TRAY_RATE20: filter->SetPressRate(20); break;
                            default:
                                break;
                        }
                    }
                }
                break;

            case WM_DESTROY:
                PostQuitMessage(0);
                break;

            default:
                return DefWindowProc(hwnd, uMsg, wParam, lParam);
        }

        return 0;
    }
};

KeyboardFilter* KeyboardFilter::s_instance = nullptr;

int WINAPI WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow) {
    (void)hInstance;
    (void)hPrevInstance;
    (void)lpCmdLine;
    (void)nCmdShow;

    // 检查是否已有实例在运行
    HANDLE hMutex = CreateMutex(nullptr, TRUE, L"KeyboardFilterMutex");
    if (GetLastError() == ERROR_ALREADY_EXISTS) {
        MessageBox(nullptr, L"键盘防抖工具已在运行中！\n\n请检查系统托盘图标。", L"提示", MB_OK | MB_ICONWARNING);
        CloseHandle(hMutex);
        return 1;
    }

    // 运行主程序
    KeyboardFilter filter;
    filter.Run();

    // 释放互斥体
    CloseHandle(hMutex);
    return 0;
}
