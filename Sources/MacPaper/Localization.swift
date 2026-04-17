import Foundation
import Combine

enum AppLang: String, CaseIterable, Identifiable {
    case en, ru
    var id: String { rawValue }
    var nativeLabel: String {
        switch self {
        case .en: return "English"
        case .ru: return "Русский"
        }
    }
}

/// Tiny i18n hub. Observable so SwiftUI re-renders on language change.
final class Localizer: ObservableObject {
    static let shared = Localizer()
    private static let defaultsKey = "MacPaper.Language"

    @Published var lang: AppLang {
        didSet {
            UserDefaults.standard.set(lang.rawValue, forKey: Self.defaultsKey)
            NotificationCenter.default.post(name: .languageDidChange, object: nil)
        }
    }

    private init() {
        if let raw = UserDefaults.standard.string(forKey: Self.defaultsKey),
           let l = AppLang(rawValue: raw) {
            self.lang = l
        } else {
            let pref = Locale.preferredLanguages.first ?? "en"
            self.lang = pref.hasPrefix("ru") ? .ru : .en
        }
    }

    /// Translate a string key. Falls back to the key itself if missing.
    func t(_ key: String) -> String {
        strings[lang]?[key] ?? strings[.en]?[key] ?? key
    }

    private let strings: [AppLang: [String: String]] = [
        .en: [
            // Sidebar / sections
            "app.name": "MacPaper",
            "sec.wallpaper": "Wallpaper",
            "sec.library": "Library",
            "sec.displays": "Displays",
            "sec.adjustments": "Adjustments",
            "sec.playback": "Playback",
            "sec.license": "License",

            // Common
            "common.stop": "Stop",
            "common.start": "Start",
            "common.reset": "Reset",
            "common.resetAll": "Reset all",
            "common.apply": "Apply",
            "common.paste": "Paste",
            "common.assign": "Assign…",
            "common.addFiles": "Add files…",
            "common.signOut": "Sign out",
            "common.language": "Language",

            // Wallpaper
            "wallpaper.current": "Current wallpaper",
            "wallpaper.chooseSource": "Choose a source",
            "wallpaper.chooseVideo": "Choose video file…",
            "wallpaper.addLibrary": "Add to Library",
            "wallpaper.urlPlaceholder": "Paste a web URL (https://…)",
            "wallpaper.none": "—",

            // Library
            "library.count": "%d items",
            "library.empty.title": "Your library is empty",
            "library.empty.desc": "Add some .mp4 / .mov files to get started.",

            // Displays
            "displays.connected": "%d connected",
            "displays.usingGlobal": "• using global wallpaper",

            // Adjustments
            "adj.brightness": "Brightness",
            "adj.blur": "Blur",
            "adj.speed": "Playback speed",
            "adj.mute": "Mute audio",
            "adj.fit": "Fit",

            // Playback
            "play.playlist": "Playlist",
            "play.playlist.desc": "Rotate through your library on an interval.",
            "play.shuffle": "Shuffle",
            "play.interval": "Interval",
            "play.advanceNow": "Advance now",
            "play.smartPause": "Smart Pause",
            "play.sp.fullscreen": "Pause on fullscreen app",
            "play.sp.lowpower": "Pause in Low Power Mode",
            "play.int.1m": "1 min",
            "play.int.5m": "5 min",
            "play.int.15m": "15 min",
            "play.int.30m": "30 min",
            "play.int.1h": "1 hour",
            "play.int.4h": "4 hours",

            // License
            "lic.licensed": "Licensed",
            "lic.unlicensed": "Unlicensed (trial)",
            "lic.key": "License key",
            "lic.activate": "Activate",
            "lic.buyTelegram": "Buy on Telegram",
            "lic.status.contacting": "Contacting server…",
            "lic.status.activated": "Activated successfully.",

            // Footer sidebar
            "footer.licensed": "Licensed · %@",
            "footer.unlicensed": "Unlicensed",
        ],
        .ru: [
            // Sidebar / sections
            "app.name": "MacPaper",
            "sec.wallpaper": "Обои",
            "sec.library": "Библиотека",
            "sec.displays": "Мониторы",
            "sec.adjustments": "Настройка",
            "sec.playback": "Воспроизведение",
            "sec.license": "Лицензия",

            // Common
            "common.stop": "Стоп",
            "common.start": "Старт",
            "common.reset": "Сбросить",
            "common.resetAll": "Сбросить всё",
            "common.apply": "Применить",
            "common.paste": "Вставить",
            "common.assign": "Назначить…",
            "common.addFiles": "Добавить файлы…",
            "common.signOut": "Выйти",
            "common.language": "Язык",

            // Wallpaper
            "wallpaper.current": "Сейчас на экране",
            "wallpaper.chooseSource": "Выбрать источник",
            "wallpaper.chooseVideo": "Выбрать видео…",
            "wallpaper.addLibrary": "В библиотеку",
            "wallpaper.urlPlaceholder": "Вставь ссылку (https://…)",
            "wallpaper.none": "—",

            // Library
            "library.count": "%d файлов",
            "library.empty.title": "Библиотека пустая",
            "library.empty.desc": "Добавь пару .mp4 / .mov — и поехали.",

            // Displays
            "displays.connected": "Подключено: %d",
            "displays.usingGlobal": "• общие обои",

            // Adjustments
            "adj.brightness": "Яркость",
            "adj.blur": "Блюр",
            "adj.speed": "Скорость",
            "adj.mute": "Без звука",
            "adj.fit": "Как вписать",

            // Playback
            "play.playlist": "Плейлист",
            "play.playlist.desc": "Прокручивать библиотеку по таймеру.",
            "play.shuffle": "Перемешать",
            "play.interval": "Интервал",
            "play.advanceNow": "Следующее",
            "play.smartPause": "Умная пауза",
            "play.sp.fullscreen": "Пауза в полноэкране",
            "play.sp.lowpower": "Пауза на батарее",
            "play.int.1m": "1 мин",
            "play.int.5m": "5 мин",
            "play.int.15m": "15 мин",
            "play.int.30m": "30 мин",
            "play.int.1h": "1 час",
            "play.int.4h": "4 часа",

            // License
            "lic.licensed": "Активирована",
            "lic.unlicensed": "Нет лицензии",
            "lic.key": "Ключ",
            "lic.activate": "Активировать",
            "lic.buyTelegram": "Купить в Telegram",
            "lic.status.contacting": "Связываюсь с сервером…",
            "lic.status.activated": "Готово, активирована.",

            // Footer sidebar
            "footer.licensed": "Активна · %@",
            "footer.unlicensed": "Нет лицензии",
        ]
    ]
}

extension Notification.Name {
    static let languageDidChange = Notification.Name("MacPaper.languageDidChange")
}
