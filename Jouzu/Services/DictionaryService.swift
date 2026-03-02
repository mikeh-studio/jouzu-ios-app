import Foundation
import SQLite3

/// Provides JMdict dictionary lookups via bundled SQLite database
final class DictionaryService: Sendable {

    // Initialized once in init(), then read-only — safe across threads
    nonisolated(unsafe) private var db: OpaquePointer?

    struct DictionaryEntry {
        let word: String
        let reading: String
        let definitions: [String]
        let partOfSpeech: String
    }

    init() {
        openDatabase()
    }

    deinit {
        if let db {
            sqlite3_close(db)
        }
    }

    // MARK: - Database Setup

    private func openDatabase() {
        // Try bundled database first
        if let bundledPath = Bundle.main.path(forResource: "jmdict", ofType: "sqlite") {
            if sqlite3_open_v2(bundledPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK {
                return
            }
        }

        // Create in-memory database with common entries for development
        createDevelopmentDatabase()
    }

    private func createDevelopmentDatabase() {
        guard sqlite3_open(":memory:", &db) == SQLITE_OK else { return }

        let createSQL = """
        CREATE TABLE IF NOT EXISTS entries (
            id INTEGER PRIMARY KEY,
            kanji TEXT,
            reading TEXT,
            definition TEXT,
            pos TEXT
        );
        CREATE INDEX IF NOT EXISTS idx_kanji ON entries(kanji);
        CREATE INDEX IF NOT EXISTS idx_reading ON entries(reading);
        """

        sqlite3_exec(db, createSQL, nil, nil, nil)

        // Seed with common words for development/demo
        let seedEntries: [(String, String, String, String)] = [
            ("食べる", "たべる", "to eat", "verb"),
            ("飲む", "のむ", "to drink", "verb"),
            ("行く", "いく", "to go", "verb"),
            ("来る", "くる", "to come", "verb"),
            ("見る", "みる", "to see; to look; to watch", "verb"),
            ("聞く", "きく", "to hear; to listen; to ask", "verb"),
            ("読む", "よむ", "to read", "verb"),
            ("書く", "かく", "to write", "verb"),
            ("話す", "はなす", "to speak; to talk", "verb"),
            ("買う", "かう", "to buy", "verb"),
            ("走る", "はしる", "to run", "verb"),
            ("歩く", "あるく", "to walk", "verb"),
            ("思う", "おもう", "to think; to feel", "verb"),
            ("知る", "しる", "to know", "verb"),
            ("住む", "すむ", "to live; to reside", "verb"),
            ("待つ", "まつ", "to wait", "verb"),
            ("使う", "つかう", "to use", "verb"),
            ("作る", "つくる", "to make; to create", "verb"),
            ("持つ", "もつ", "to hold; to have", "verb"),
            ("言う", "いう", "to say", "verb"),
            ("猫", "ねこ", "cat", "noun"),
            ("犬", "いぬ", "dog", "noun"),
            ("学校", "がっこう", "school", "noun"),
            ("先生", "せんせい", "teacher", "noun"),
            ("学生", "がくせい", "student", "noun"),
            ("本", "ほん", "book", "noun"),
            ("水", "みず", "water", "noun"),
            ("日本", "にほん", "Japan", "noun"),
            ("日本語", "にほんご", "Japanese language", "noun"),
            ("英語", "えいご", "English language", "noun"),
            ("人", "ひと", "person", "noun"),
            ("男", "おとこ", "man", "noun"),
            ("女", "おんな", "woman", "noun"),
            ("子供", "こども", "child", "noun"),
            ("友達", "ともだち", "friend", "noun"),
            ("家", "いえ", "house; home", "noun"),
            ("車", "くるま", "car", "noun"),
            ("電車", "でんしゃ", "train", "noun"),
            ("駅", "えき", "station", "noun"),
            ("時間", "じかん", "time", "noun"),
            ("今日", "きょう", "today", "noun"),
            ("明日", "あした", "tomorrow", "noun"),
            ("昨日", "きのう", "yesterday", "noun"),
            ("天気", "てんき", "weather", "noun"),
            ("食べ物", "たべもの", "food", "noun"),
            ("大きい", "おおきい", "big; large", "i-adjective"),
            ("小さい", "ちいさい", "small; little", "i-adjective"),
            ("新しい", "あたらしい", "new", "i-adjective"),
            ("古い", "ふるい", "old", "i-adjective"),
            ("良い", "よい", "good", "i-adjective"),
            ("悪い", "わるい", "bad", "i-adjective"),
            ("高い", "たかい", "tall; expensive", "i-adjective"),
            ("安い", "やすい", "cheap; inexpensive", "i-adjective"),
            ("美しい", "うつくしい", "beautiful", "i-adjective"),
            ("楽しい", "たのしい", "fun; enjoyable", "i-adjective"),
            ("きれい", "きれい", "pretty; clean", "na-adjective"),
            ("静か", "しずか", "quiet", "na-adjective"),
            ("元気", "げんき", "healthy; energetic", "na-adjective"),
            ("便利", "べんり", "convenient", "na-adjective"),
            ("有名", "ゆうめい", "famous", "na-adjective"),
        ]

        let insertSQL = "INSERT INTO entries (kanji, reading, definition, pos) VALUES (?, ?, ?, ?)"
        var stmt: OpaquePointer?

        if sqlite3_prepare_v2(db, insertSQL, -1, &stmt, nil) == SQLITE_OK {
            for entry in seedEntries {
                sqlite3_bind_text(stmt, 1, (entry.0 as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 2, (entry.1 as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 3, (entry.2 as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 4, (entry.3 as NSString).utf8String, -1, nil)
                sqlite3_step(stmt)
                sqlite3_reset(stmt)
            }
            sqlite3_finalize(stmt)
        }
    }

    // MARK: - Lookups

    /// Look up a word by its surface form or base form
    func lookup(word: String) -> [DictionaryEntry] {
        guard let db else { return [] }

        let query = "SELECT kanji, reading, definition, pos FROM entries WHERE kanji = ? OR reading = ? LIMIT 10"
        var stmt: OpaquePointer?
        var results: [DictionaryEntry] = []

        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else { return [] }

        sqlite3_bind_text(stmt, 1, (word as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 2, (word as NSString).utf8String, -1, nil)

        while sqlite3_step(stmt) == SQLITE_ROW {
            let kanji = sqlite3_column_text(stmt, 0).map(String.init(cString:)) ?? ""
            let reading = sqlite3_column_text(stmt, 1).map(String.init(cString:)) ?? ""
            let definition = sqlite3_column_text(stmt, 2).map(String.init(cString:)) ?? ""
            let pos = sqlite3_column_text(stmt, 3).map(String.init(cString:)) ?? ""

            guard !kanji.isEmpty else { continue }

            results.append(DictionaryEntry(
                word: kanji,
                reading: reading,
                definitions: definition.components(separatedBy: "; "),
                partOfSpeech: pos
            ))
        }

        sqlite3_finalize(stmt)
        return results
    }

    /// Enrich tokens with dictionary definitions
    func enrichTokens(_ tokens: [Token]) -> [Token] {
        tokens.map { token in
            var enriched = token

            // Try base form first, then surface form
            let entries = lookup(word: token.baseForm)
            let fallback = entries.isEmpty ? lookup(word: token.surface) : entries

            if let entry = fallback.first {
                enriched.definitions = entry.definitions
            }

            return enriched
        }
    }
}
