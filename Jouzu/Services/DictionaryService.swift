import Foundation
import SQLite3
import Translation

/// Provides JMdict dictionary lookups via bundled SQLite database
final class DictionaryService: Sendable {
    enum DatabaseSource: Equatable {
        case bundled
        case custom
        case development
    }

    // Initialized once in init(), then read-only — safe across threads
    nonisolated(unsafe) private var db: OpaquePointer?
    private let databasePath: String?
    nonisolated(unsafe) private var resolvedDatabaseSource: DatabaseSource = .development

    var databaseSource: DatabaseSource {
        resolvedDatabaseSource
    }

    struct DictionaryEntry {
        let word: String
        let reading: String
        let definitions: [String]
        let partOfSpeech: String
    }

    init(databasePath: String? = Bundle.main.path(forResource: "jmdict", ofType: "sqlite")) {
        self.databasePath = databasePath
        openDatabase()
    }

    deinit {
        if let db {
            sqlite3_close(db)
        }
    }

    // MARK: - Database Setup

    private func openDatabase() {
        if let databasePath,
           sqlite3_open_v2(databasePath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK {
            resolvedDatabaseSource = databasePath.hasSuffix("/jmdict.sqlite") ? .bundled : .custom
            return
        }

        if let db {
            sqlite3_close(db)
            self.db = nil
        }

        // Create in-memory database with common entries for development
        createDevelopmentDatabase()
    }

    private func createDevelopmentDatabase() {
        guard sqlite3_open(":memory:", &db) == SQLITE_OK else { return }
        resolvedDatabaseSource = .development

        let createSQL = """
        CREATE TABLE IF NOT EXISTS entries (
            id INTEGER PRIMARY KEY,
            kanji TEXT,
            reading TEXT,
            definition TEXT,
            pos TEXT,
            priority INTEGER DEFAULT 9999
        );
        CREATE INDEX IF NOT EXISTS idx_kanji ON entries(kanji);
        CREATE INDEX IF NOT EXISTS idx_reading ON entries(reading);
        """

        sqlite3_exec(db, createSQL, nil, nil, nil)

        // Seed with JLPT N5/N4 vocabulary (~510 entries)
        let seedEntries: [(String, String, String, String)] = [
            // MARK: - Verbs (N5)
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
            ("寝る", "ねる", "to sleep; to go to bed", "verb"),
            ("起きる", "おきる", "to wake up; to get up", "verb"),
            ("入る", "はいる", "to enter", "verb"),
            ("出る", "でる", "to go out; to leave", "verb"),
            ("立つ", "たつ", "to stand", "verb"),
            ("座る", "すわる", "to sit", "verb"),
            ("帰る", "かえる", "to return; to go home", "verb"),
            ("出かける", "でかける", "to go out", "verb"),
            ("開ける", "あける", "to open", "verb"),
            ("閉める", "しめる", "to close; to shut", "verb"),
            ("つける", "つける", "to turn on; to attach", "verb"),
            ("消す", "けす", "to turn off; to erase", "verb"),
            ("洗う", "あらう", "to wash", "verb"),
            ("遊ぶ", "あそぶ", "to play; to have fun", "verb"),
            ("泳ぐ", "およぐ", "to swim", "verb"),
            ("歌う", "うたう", "to sing", "verb"),
            ("踊る", "おどる", "to dance", "verb"),
            ("弾く", "ひく", "to play (instrument)", "verb"),
            ("撮る", "とる", "to take (a photo)", "verb"),
            ("取る", "とる", "to take; to get", "verb"),
            ("置く", "おく", "to put; to place", "verb"),
            ("押す", "おす", "to push; to press", "verb"),
            ("引く", "ひく", "to pull; to draw", "verb"),
            ("切る", "きる", "to cut", "verb"),
            ("着る", "きる", "to wear (upper body)", "verb"),
            ("脱ぐ", "ぬぐ", "to take off (clothes)", "verb"),
            ("履く", "はく", "to wear (lower body); to put on (shoes)", "verb"),
            ("かぶる", "かぶる", "to wear (on head)", "verb"),
            ("かける", "かける", "to wear (glasses); to hang", "verb"),
            ("働く", "はたらく", "to work", "verb"),
            ("休む", "やすむ", "to rest; to take a day off", "verb"),
            ("始まる", "はじまる", "to begin (intransitive)", "verb"),
            ("終わる", "おわる", "to end; to finish", "verb"),
            ("会う", "あう", "to meet", "verb"),
            ("分かる", "わかる", "to understand", "verb"),
            ("教える", "おしえる", "to teach; to tell", "verb"),
            ("習う", "ならう", "to learn", "verb"),
            ("勉強する", "べんきょうする", "to study", "verb"),
            ("練習する", "れんしゅうする", "to practice", "verb"),
            ("答える", "こたえる", "to answer", "verb"),
            ("質問する", "しつもんする", "to ask a question", "verb"),
            ("出す", "だす", "to take out; to submit", "verb"),
            ("入れる", "いれる", "to put in; to insert", "verb"),
            ("返す", "かえす", "to return (something)", "verb"),
            ("借りる", "かりる", "to borrow", "verb"),
            ("貸す", "かす", "to lend", "verb"),
            ("あげる", "あげる", "to give", "verb"),
            ("もらう", "もらう", "to receive", "verb"),
            ("くれる", "くれる", "to give (to me)", "verb"),
            ("売る", "うる", "to sell", "verb"),
            ("払う", "はらう", "to pay", "verb"),
            ("送る", "おくる", "to send", "verb"),
            ("届ける", "とどける", "to deliver", "verb"),
            ("呼ぶ", "よぶ", "to call; to invite", "verb"),
            ("死ぬ", "しぬ", "to die", "verb"),
            ("生まれる", "うまれる", "to be born", "verb"),
            ("飛ぶ", "とぶ", "to fly; to jump", "verb"),
            ("乗る", "のる", "to ride; to get on", "verb"),
            ("降りる", "おりる", "to get off; to descend", "verb"),
            ("渡る", "わたる", "to cross", "verb"),
            ("曲がる", "まがる", "to turn; to bend", "verb"),
            ("止まる", "とまる", "to stop", "verb"),
            ("止める", "とめる", "to stop (something)", "verb"),
            ("登る", "のぼる", "to climb", "verb"),
            ("動く", "うごく", "to move", "verb"),
            ("変わる", "かわる", "to change (intransitive)", "verb"),
            ("決める", "きめる", "to decide", "verb"),
            ("見せる", "みせる", "to show", "verb"),
            ("忘れる", "わすれる", "to forget", "verb"),
            ("覚える", "おぼえる", "to remember; to memorize", "verb"),
            ("考える", "かんがえる", "to think; to consider", "verb"),
            ("信じる", "しんじる", "to believe", "verb"),
            ("頼む", "たのむ", "to request; to ask a favor", "verb"),
            ("手伝う", "てつだう", "to help; to assist", "verb"),
            ("困る", "こまる", "to be troubled; to be in difficulty", "verb"),
            ("怒る", "おこる", "to get angry", "verb"),
            ("笑う", "わらう", "to laugh; to smile", "verb"),
            ("泣く", "なく", "to cry", "verb"),
            ("疲れる", "つかれる", "to get tired", "verb"),
            ("転ぶ", "ころぶ", "to fall down", "verb"),
            ("壊れる", "こわれる", "to break (intransitive)", "verb"),
            ("壊す", "こわす", "to break (transitive)", "verb"),
            ("直す", "なおす", "to fix; to repair", "verb"),
            ("変える", "かえる", "to change (transitive)", "verb"),
            ("並ぶ", "ならぶ", "to line up", "verb"),
            ("並べる", "ならべる", "to arrange; to line up (transitive)", "verb"),
            ("選ぶ", "えらぶ", "to choose; to select", "verb"),
            ("集める", "あつめる", "to collect; to gather", "verb"),
            ("捨てる", "すてる", "to throw away", "verb"),
            ("拾う", "ひろう", "to pick up", "verb"),
            ("落とす", "おとす", "to drop", "verb"),
            ("落ちる", "おちる", "to fall", "verb"),
            ("運ぶ", "はこぶ", "to carry; to transport", "verb"),
            ("引っ越す", "ひっこす", "to move (residence)", "verb"),
            ("触る", "さわる", "to touch", "verb"),
            ("鳴る", "なる", "to ring; to sound", "verb"),
            ("咲く", "さく", "to bloom", "verb"),
            ("育てる", "そだてる", "to raise; to grow", "verb"),
            ("足りる", "たりる", "to be sufficient", "verb"),
            ("間に合う", "まにあう", "to be in time", "verb"),
            ("受ける", "うける", "to receive; to take (exam)", "verb"),
            ("探す", "さがす", "to search for; to look for", "verb"),
            ("見つける", "みつける", "to find; to discover", "verb"),

            // MARK: - Nouns: People & Family
            ("猫", "ねこ", "cat", "noun"),
            ("犬", "いぬ", "dog", "noun"),
            ("人", "ひと", "person", "noun"),
            ("男", "おとこ", "man", "noun"),
            ("女", "おんな", "woman", "noun"),
            ("子供", "こども", "child", "noun"),
            ("友達", "ともだち", "friend", "noun"),
            ("先生", "せんせい", "teacher", "noun"),
            ("学生", "がくせい", "student", "noun"),
            ("男の子", "おとこのこ", "boy", "noun"),
            ("女の子", "おんなのこ", "girl", "noun"),
            ("赤ちゃん", "あかちゃん", "baby", "noun"),
            ("大人", "おとな", "adult", "noun"),
            ("お母さん", "おかあさん", "mother", "noun"),
            ("お父さん", "おとうさん", "father", "noun"),
            ("お兄さん", "おにいさん", "older brother", "noun"),
            ("お姉さん", "おねえさん", "older sister", "noun"),
            ("弟", "おとうと", "younger brother", "noun"),
            ("妹", "いもうと", "younger sister", "noun"),
            ("家族", "かぞく", "family", "noun"),
            ("両親", "りょうしん", "parents", "noun"),
            ("兄弟", "きょうだい", "siblings", "noun"),
            ("奥さん", "おくさん", "wife (polite)", "noun"),
            ("主人", "しゅじん", "husband", "noun"),
            ("彼", "かれ", "he; boyfriend", "noun"),
            ("彼女", "かのじょ", "she; girlfriend", "noun"),
            ("皆", "みんな", "everyone", "noun"),
            ("自分", "じぶん", "oneself", "noun"),
            ("隣", "となり", "next to; neighbor", "noun"),

            // MARK: - Nouns: Places
            ("学校", "がっこう", "school", "noun"),
            ("家", "いえ", "house; home", "noun"),
            ("駅", "えき", "station", "noun"),
            ("日本", "にほん", "Japan", "noun"),
            ("病院", "びょういん", "hospital", "noun"),
            ("銀行", "ぎんこう", "bank", "noun"),
            ("郵便局", "ゆうびんきょく", "post office", "noun"),
            ("図書館", "としょかん", "library", "noun"),
            ("公園", "こうえん", "park", "noun"),
            ("会社", "かいしゃ", "company", "noun"),
            ("店", "みせ", "shop; store", "noun"),
            ("レストラン", "れすとらん", "restaurant", "noun"),
            ("ホテル", "ほてる", "hotel", "noun"),
            ("空港", "くうこう", "airport", "noun"),
            ("部屋", "へや", "room", "noun"),
            ("台所", "だいどころ", "kitchen", "noun"),
            ("お手洗い", "おてあらい", "restroom", "noun"),
            ("入口", "いりぐち", "entrance", "noun"),
            ("出口", "でぐち", "exit", "noun"),
            ("場所", "ばしょ", "place", "noun"),
            ("外", "そと", "outside", "noun"),
            ("中", "なか", "inside; middle", "noun"),
            ("上", "うえ", "above; on top", "noun"),
            ("下", "した", "below; under", "noun"),
            ("前", "まえ", "front; before", "noun"),
            ("後ろ", "うしろ", "behind; back", "noun"),
            ("右", "みぎ", "right", "noun"),
            ("左", "ひだり", "left", "noun"),
            ("近く", "ちかく", "nearby", "noun"),
            ("向こう", "むこう", "over there; opposite side", "noun"),
            ("町", "まち", "town", "noun"),
            ("道", "みち", "road; way", "noun"),
            ("橋", "はし", "bridge", "noun"),
            ("神社", "じんじゃ", "Shinto shrine", "noun"),
            ("お寺", "おてら", "Buddhist temple", "noun"),
            ("教室", "きょうしつ", "classroom", "noun"),

            // MARK: - Nouns: Time
            ("時間", "じかん", "time", "noun"),
            ("今日", "きょう", "today", "noun"),
            ("明日", "あした", "tomorrow", "noun"),
            ("昨日", "きのう", "yesterday", "noun"),
            ("今", "いま", "now", "noun"),
            ("朝", "あさ", "morning", "noun"),
            ("昼", "ひる", "noon; daytime", "noun"),
            ("夜", "よる", "night; evening", "noun"),
            ("夕方", "ゆうがた", "evening", "noun"),
            ("午前", "ごぜん", "morning; AM", "noun"),
            ("午後", "ごご", "afternoon; PM", "noun"),
            ("毎日", "まいにち", "every day", "noun"),
            ("毎朝", "まいあさ", "every morning", "noun"),
            ("毎晩", "まいばん", "every night", "noun"),
            ("毎週", "まいしゅう", "every week", "noun"),
            ("毎月", "まいつき", "every month", "noun"),
            ("毎年", "まいとし", "every year", "noun"),
            ("今週", "こんしゅう", "this week", "noun"),
            ("先週", "せんしゅう", "last week", "noun"),
            ("来週", "らいしゅう", "next week", "noun"),
            ("今月", "こんげつ", "this month", "noun"),
            ("先月", "せんげつ", "last month", "noun"),
            ("来月", "らいげつ", "next month", "noun"),
            ("今年", "ことし", "this year", "noun"),
            ("去年", "きょねん", "last year", "noun"),
            ("来年", "らいねん", "next year", "noun"),
            ("誕生日", "たんじょうび", "birthday", "noun"),
            ("休み", "やすみ", "holiday; rest; day off", "noun"),

            // MARK: - Nouns: Things & Objects
            ("本", "ほん", "book", "noun"),
            ("水", "みず", "water", "noun"),
            ("車", "くるま", "car", "noun"),
            ("電車", "でんしゃ", "train", "noun"),
            ("天気", "てんき", "weather", "noun"),
            ("食べ物", "たべもの", "food", "noun"),
            ("飲み物", "のみもの", "drink; beverage", "noun"),
            ("新聞", "しんぶん", "newspaper", "noun"),
            ("雑誌", "ざっし", "magazine", "noun"),
            ("手紙", "てがみ", "letter", "noun"),
            ("写真", "しゃしん", "photograph", "noun"),
            ("映画", "えいが", "movie; film", "noun"),
            ("音楽", "おんがく", "music", "noun"),
            ("歌", "うた", "song", "noun"),
            ("花", "はな", "flower", "noun"),
            ("木", "き", "tree; wood", "noun"),
            ("山", "やま", "mountain", "noun"),
            ("川", "かわ", "river", "noun"),
            ("海", "うみ", "sea; ocean", "noun"),
            ("空", "そら", "sky", "noun"),
            ("雨", "あめ", "rain", "noun"),
            ("雪", "ゆき", "snow", "noun"),
            ("風", "かぜ", "wind", "noun"),
            ("電話", "でんわ", "telephone", "noun"),
            ("お金", "おかね", "money", "noun"),
            ("鍵", "かぎ", "key", "noun"),
            ("傘", "かさ", "umbrella", "noun"),
            ("鞄", "かばん", "bag", "noun"),
            ("財布", "さいふ", "wallet", "noun"),
            ("時計", "とけい", "watch; clock", "noun"),
            ("眼鏡", "めがね", "glasses", "noun"),
            ("靴", "くつ", "shoes", "noun"),
            ("帽子", "ぼうし", "hat; cap", "noun"),
            ("服", "ふく", "clothes", "noun"),
            ("机", "つくえ", "desk", "noun"),
            ("椅子", "いす", "chair", "noun"),
            ("窓", "まど", "window", "noun"),
            ("ドア", "どあ", "door", "noun"),
            ("テーブル", "てーぶる", "table", "noun"),
            ("ベッド", "べっど", "bed", "noun"),
            ("お茶", "おちゃ", "tea", "noun"),
            ("ご飯", "ごはん", "rice; meal", "noun"),
            ("パン", "ぱん", "bread", "noun"),
            ("肉", "にく", "meat", "noun"),
            ("魚", "さかな", "fish", "noun"),
            ("野菜", "やさい", "vegetables", "noun"),
            ("果物", "くだもの", "fruit", "noun"),
            ("卵", "たまご", "egg", "noun"),
            ("牛乳", "ぎゅうにゅう", "milk", "noun"),
            ("薬", "くすり", "medicine", "noun"),
            ("切手", "きって", "postage stamp", "noun"),
            ("切符", "きっぷ", "ticket", "noun"),
            ("荷物", "にもつ", "luggage; baggage", "noun"),
            ("プレゼント", "ぷれぜんと", "present; gift", "noun"),

            // MARK: - Nouns: Language & Education
            ("日本語", "にほんご", "Japanese language", "noun"),
            ("英語", "えいご", "English language", "noun"),
            ("言葉", "ことば", "word; language", "noun"),
            ("漢字", "かんじ", "kanji; Chinese character", "noun"),
            ("文", "ぶん", "sentence", "noun"),
            ("意味", "いみ", "meaning", "noun"),
            ("名前", "なまえ", "name", "noun"),
            ("質問", "しつもん", "question", "noun"),
            ("答え", "こたえ", "answer", "noun"),
            ("問題", "もんだい", "problem; question", "noun"),
            ("テスト", "てすと", "test", "noun"),
            ("宿題", "しゅくだい", "homework", "noun"),
            ("授業", "じゅぎょう", "class; lesson", "noun"),
            ("試験", "しけん", "exam", "noun"),

            // MARK: - Nouns: Body & Health
            ("体", "からだ", "body", "noun"),
            ("頭", "あたま", "head", "noun"),
            ("顔", "かお", "face", "noun"),
            ("目", "め", "eye", "noun"),
            ("耳", "みみ", "ear", "noun"),
            ("口", "くち", "mouth", "noun"),
            ("歯", "は", "tooth", "noun"),
            ("鼻", "はな", "nose", "noun"),
            ("手", "て", "hand", "noun"),
            ("足", "あし", "foot; leg", "noun"),
            ("指", "ゆび", "finger", "noun"),
            ("お腹", "おなか", "stomach", "noun"),
            ("背", "せ", "height; back", "noun"),
            ("声", "こえ", "voice", "noun"),
            ("病気", "びょうき", "illness; sickness", "noun"),
            ("風邪", "かぜ", "cold (illness)", "noun"),
            ("熱", "ねつ", "fever; heat", "noun"),

            // MARK: - Nouns: Abstract & Other
            ("仕事", "しごと", "work; job", "noun"),
            ("旅行", "りょこう", "travel; trip", "noun"),
            ("散歩", "さんぽ", "walk; stroll", "noun"),
            ("料理", "りょうり", "cooking; cuisine", "noun"),
            ("買い物", "かいもの", "shopping", "noun"),
            ("趣味", "しゅみ", "hobby", "noun"),
            ("約束", "やくそく", "promise; appointment", "noun"),
            ("準備", "じゅんび", "preparation", "noun"),
            ("経験", "けいけん", "experience", "noun"),
            ("気持ち", "きもち", "feeling", "noun"),
            ("心", "こころ", "heart; mind", "noun"),
            ("夢", "ゆめ", "dream", "noun"),
            ("力", "ちから", "power; strength", "noun"),
            ("色", "いろ", "color", "noun"),
            ("形", "かたち", "shape; form", "noun"),
            ("音", "おと", "sound", "noun"),
            ("話", "はなし", "story; talk", "noun"),
            ("事", "こと", "thing (abstract)", "noun"),
            ("物", "もの", "thing (concrete)", "noun"),
            ("所", "ところ", "place", "noun"),
            ("方", "ほう", "direction; way", "noun"),
            ("最初", "さいしょ", "first; beginning", "noun"),
            ("最後", "さいご", "last; end", "noun"),
            ("大切", "たいせつ", "important; precious", "noun"),
            ("安全", "あんぜん", "safety; security", "noun"),
            ("世界", "せかい", "world", "noun"),
            ("社会", "しゃかい", "society", "noun"),
            ("文化", "ぶんか", "culture", "noun"),
            ("生活", "せいかつ", "life; livelihood", "noun"),
            ("天気予報", "てんきよほう", "weather forecast", "noun"),
            ("番号", "ばんごう", "number", "noun"),
            ("住所", "じゅうしょ", "address", "noun"),
            ("地図", "ちず", "map", "noun"),
            ("お祭り", "おまつり", "festival", "noun"),
            ("季節", "きせつ", "season", "noun"),
            ("春", "はる", "spring", "noun"),
            ("夏", "なつ", "summer", "noun"),
            ("秋", "あき", "autumn; fall", "noun"),
            ("冬", "ふゆ", "winter", "noun"),

            // MARK: - I-Adjectives
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
            ("長い", "ながい", "long", "i-adjective"),
            ("短い", "みじかい", "short", "i-adjective"),
            ("広い", "ひろい", "wide; spacious", "i-adjective"),
            ("狭い", "せまい", "narrow; cramped", "i-adjective"),
            ("多い", "おおい", "many; a lot", "i-adjective"),
            ("少ない", "すくない", "few; a little", "i-adjective"),
            ("近い", "ちかい", "near; close", "i-adjective"),
            ("遠い", "とおい", "far; distant", "i-adjective"),
            ("速い", "はやい", "fast; quick", "i-adjective"),
            ("遅い", "おそい", "slow; late", "i-adjective"),
            ("早い", "はやい", "early", "i-adjective"),
            ("暑い", "あつい", "hot (weather)", "i-adjective"),
            ("寒い", "さむい", "cold (weather)", "i-adjective"),
            ("暖かい", "あたたかい", "warm", "i-adjective"),
            ("涼しい", "すずしい", "cool; refreshing", "i-adjective"),
            ("熱い", "あつい", "hot (to the touch)", "i-adjective"),
            ("冷たい", "つめたい", "cold (to the touch)", "i-adjective"),
            ("甘い", "あまい", "sweet", "i-adjective"),
            ("辛い", "からい", "spicy; hot", "i-adjective"),
            ("苦い", "にがい", "bitter", "i-adjective"),
            ("酸っぱい", "すっぱい", "sour", "i-adjective"),
            ("おいしい", "おいしい", "delicious; tasty", "i-adjective"),
            ("まずい", "まずい", "bad tasting; awful", "i-adjective"),
            ("強い", "つよい", "strong", "i-adjective"),
            ("弱い", "よわい", "weak", "i-adjective"),
            ("明るい", "あかるい", "bright; cheerful", "i-adjective"),
            ("暗い", "くらい", "dark; gloomy", "i-adjective"),
            ("重い", "おもい", "heavy", "i-adjective"),
            ("軽い", "かるい", "light (weight)", "i-adjective"),
            ("太い", "ふとい", "thick; fat", "i-adjective"),
            ("細い", "ほそい", "thin; slender", "i-adjective"),
            ("若い", "わかい", "young", "i-adjective"),
            ("白い", "しろい", "white", "i-adjective"),
            ("黒い", "くろい", "black", "i-adjective"),
            ("赤い", "あかい", "red", "i-adjective"),
            ("青い", "あおい", "blue; green", "i-adjective"),
            ("黄色い", "きいろい", "yellow", "i-adjective"),
            ("丸い", "まるい", "round", "i-adjective"),
            ("うるさい", "うるさい", "noisy; annoying", "i-adjective"),
            ("忙しい", "いそがしい", "busy", "i-adjective"),
            ("難しい", "むずかしい", "difficult", "i-adjective"),
            ("易しい", "やさしい", "easy; simple", "i-adjective"),
            ("優しい", "やさしい", "kind; gentle", "i-adjective"),
            ("嬉しい", "うれしい", "happy; glad", "i-adjective"),
            ("悲しい", "かなしい", "sad", "i-adjective"),
            ("寂しい", "さびしい", "lonely", "i-adjective"),
            ("怖い", "こわい", "scary; frightening", "i-adjective"),
            ("痛い", "いたい", "painful; ouch", "i-adjective"),
            ("眠い", "ねむい", "sleepy", "i-adjective"),
            ("面白い", "おもしろい", "interesting; funny", "i-adjective"),
            ("つまらない", "つまらない", "boring; dull", "i-adjective"),
            ("欲しい", "ほしい", "wanted; desired", "i-adjective"),
            ("危ない", "あぶない", "dangerous", "i-adjective"),
            ("珍しい", "めずらしい", "rare; unusual", "i-adjective"),
            ("正しい", "ただしい", "correct; right", "i-adjective"),
            ("すごい", "すごい", "amazing; terrible", "i-adjective"),

            // MARK: - Na-Adjectives
            ("きれい", "きれい", "pretty; clean", "na-adjective"),
            ("静か", "しずか", "quiet", "na-adjective"),
            ("元気", "げんき", "healthy; energetic", "na-adjective"),
            ("便利", "べんり", "convenient", "na-adjective"),
            ("有名", "ゆうめい", "famous", "na-adjective"),
            ("好き", "すき", "liked; favorite", "na-adjective"),
            ("嫌い", "きらい", "disliked; hated", "na-adjective"),
            ("上手", "じょうず", "skillful; good at", "na-adjective"),
            ("下手", "へた", "unskillful; bad at", "na-adjective"),
            ("丈夫", "じょうぶ", "strong; durable", "na-adjective"),
            ("大変", "たいへん", "tough; very", "na-adjective"),
            ("大丈夫", "だいじょうぶ", "all right; OK", "na-adjective"),
            ("暇", "ひま", "free (time); not busy", "na-adjective"),
            ("賑やか", "にぎやか", "lively; bustling", "na-adjective"),
            ("親切", "しんせつ", "kind; helpful", "na-adjective"),
            ("簡単", "かんたん", "easy; simple", "na-adjective"),
            ("複雑", "ふくざつ", "complicated", "na-adjective"),
            ("立派", "りっぱ", "splendid; fine", "na-adjective"),
            ("素敵", "すてき", "lovely; wonderful", "na-adjective"),
            ("不便", "ふべん", "inconvenient", "na-adjective"),
            ("必要", "ひつよう", "necessary", "na-adjective"),
            ("特別", "とくべつ", "special", "na-adjective"),
            ("自由", "じゆう", "free; freedom", "na-adjective"),
            ("安心", "あんしん", "relief; peace of mind", "na-adjective"),
            ("心配", "しんぱい", "worry; concern", "na-adjective"),
            ("残念", "ざんねん", "regrettable; unfortunate", "na-adjective"),
            ("無理", "むり", "impossible; unreasonable", "na-adjective"),
            ("真面目", "まじめ", "serious; earnest", "na-adjective"),
            ("丁寧", "ていねい", "polite; careful", "na-adjective"),
            ("熱心", "ねっしん", "enthusiastic; eager", "na-adjective"),
            ("十分", "じゅうぶん", "enough; sufficient", "na-adjective"),
            ("駄目", "だめ", "no good; useless", "na-adjective"),
            ("嫌", "いや", "disagreeable; unpleasant", "na-adjective"),
            ("変", "へん", "strange; weird", "na-adjective"),
            ("適当", "てきとう", "suitable; appropriate", "na-adjective"),

            // MARK: - Adverbs
            ("とても", "とても", "very; extremely", "adverb"),
            ("たくさん", "たくさん", "a lot; many", "adverb"),
            ("少し", "すこし", "a little; a few", "adverb"),
            ("ちょっと", "ちょっと", "a little; slightly", "adverb"),
            ("全然", "ぜんぜん", "not at all (with negative)", "adverb"),
            ("全部", "ぜんぶ", "all; everything", "adverb"),
            ("いつも", "いつも", "always", "adverb"),
            ("よく", "よく", "often; well", "adverb"),
            ("時々", "ときどき", "sometimes", "adverb"),
            ("たまに", "たまに", "occasionally; once in a while", "adverb"),
            ("あまり", "あまり", "not very (with negative)", "adverb"),
            ("まだ", "まだ", "still; not yet", "adverb"),
            ("もう", "もう", "already; anymore", "adverb"),
            ("すぐ", "すぐ", "soon; immediately", "adverb"),
            ("ゆっくり", "ゆっくり", "slowly; at ease", "adverb"),
            ("だんだん", "だんだん", "gradually", "adverb"),
            ("初めて", "はじめて", "for the first time", "adverb"),
            ("一緒に", "いっしょに", "together", "adverb"),
            ("一番", "いちばん", "most; best; number one", "adverb"),
            ("もっと", "もっと", "more", "adverb"),
            ("ずっと", "ずっと", "for a long time; much (more)", "adverb"),
            ("たぶん", "たぶん", "probably; maybe", "adverb"),
            ("きっと", "きっと", "surely; certainly", "adverb"),
            ("本当に", "ほんとうに", "really; truly", "adverb"),
            ("特に", "とくに", "especially; particularly", "adverb"),
            ("やはり", "やはり", "as expected; after all", "adverb"),
            ("なかなか", "なかなか", "quite; rather; not easily", "adverb"),
            ("ちゃんと", "ちゃんと", "properly; perfectly", "adverb"),
            ("はっきり", "はっきり", "clearly; distinctly", "adverb"),
            ("そろそろ", "そろそろ", "soon; before long", "adverb"),
            ("だいたい", "だいたい", "roughly; approximately", "adverb"),
            ("必ず", "かならず", "certainly; without fail", "adverb"),
            ("絶対", "ぜったい", "absolutely; definitely", "adverb"),
            ("急に", "きゅうに", "suddenly", "adverb"),
            ("普通", "ふつう", "usually; ordinary", "adverb"),
            ("結構", "けっこう", "quite; fairly", "adverb"),
            ("やっと", "やっと", "at last; finally", "adverb"),

            // MARK: - Conjunctions & Interjections
            ("しかし", "しかし", "however; but", "conjunction"),
            ("でも", "でも", "but; however", "conjunction"),
            ("だから", "だから", "therefore; so", "conjunction"),
            ("それから", "それから", "and then; after that", "conjunction"),
            ("そして", "そして", "and; and then", "conjunction"),
            ("それで", "それで", "and so; therefore", "conjunction"),
            ("けれども", "けれども", "however; although", "conjunction"),
            ("または", "または", "or; otherwise", "conjunction"),
            ("つまり", "つまり", "in other words; that is to say", "conjunction"),
            ("すみません", "すみません", "excuse me; I'm sorry", "interjection"),
            ("ごめんなさい", "ごめんなさい", "I'm sorry", "interjection"),
            ("おはようございます", "おはようございます", "good morning", "interjection"),
            ("こんにちは", "こんにちは", "hello; good afternoon", "interjection"),
            ("こんばんは", "こんばんは", "good evening", "interjection"),
            ("さようなら", "さようなら", "goodbye", "interjection"),
            ("いただきます", "いただきます", "bon appetit (before eating)", "interjection"),
            ("ごちそうさま", "ごちそうさま", "thanks for the meal (after eating)", "interjection"),
            ("おめでとう", "おめでとう", "congratulations", "interjection"),
            ("いらっしゃいませ", "いらっしゃいませ", "welcome (to a shop)", "interjection"),

            // MARK: - Particles
            ("から", "から", "from; because", "particle"),
            ("まで", "まで", "until; to; as far as", "particle"),
            ("より", "より", "than; from", "particle"),
            ("ほど", "ほど", "extent; degree; about", "particle"),
            ("ばかり", "ばかり", "only; just; nothing but", "particle"),
            ("だけ", "だけ", "only; just", "particle"),
            ("しか", "しか", "only (with negative)", "particle"),
            ("ながら", "ながら", "while; although", "particle"),
            ("など", "など", "et cetera; and so on", "particle"),
            ("ぐらい", "ぐらい", "about; approximately", "particle"),

            // MARK: - Common Expressions
            ("ありがとう", "ありがとう", "thank you", "expression"),
            ("お願いします", "おねがいします", "please", "expression"),
            ("大丈夫です", "だいじょうぶです", "it's all right; I'm fine", "expression"),
            ("お元気ですか", "おげんきですか", "how are you?", "expression"),
            ("初めまして", "はじめまして", "nice to meet you", "expression"),
            ("よろしくお願いします", "よろしくおねがいします", "pleased to meet you; please take care of it", "expression"),
            ("お疲れ様です", "おつかれさまです", "good work; thank you for your efforts", "expression"),
            ("気をつけて", "きをつけて", "be careful; take care", "expression"),
            ("頑張って", "がんばって", "do your best; good luck", "expression"),
            ("久しぶり", "ひさしぶり", "long time no see", "expression"),
            ("いってきます", "いってきます", "I'm leaving (and coming back)", "expression"),
            ("いってらっしゃい", "いってらっしゃい", "have a good trip; see you later", "expression"),
            ("ただいま", "ただいま", "I'm home", "expression"),
            ("おかえりなさい", "おかえりなさい", "welcome home", "expression"),
            ("失礼します", "しつれいします", "excuse me (formal)", "expression"),
            ("お休みなさい", "おやすみなさい", "good night", "expression"),
            ("どういたしまして", "どういたしまして", "you're welcome", "expression"),
            ("ちょっと待って", "ちょっとまって", "wait a moment", "expression"),
            ("そうですね", "そうですね", "that's right; let me think", "expression"),
            ("分かりました", "わかりました", "I understand; understood", "expression"),
            ("もちろん", "もちろん", "of course", "expression"),
            ("なるほど", "なるほど", "I see; indeed", "expression"),
            ("どうぞ", "どうぞ", "please; go ahead", "expression"),
            ("いいえ", "いいえ", "no; not at all", "expression"),
            ("そうですか", "そうですか", "is that so?", "expression"),
        ]

        let insertSQL = "INSERT INTO entries (kanji, reading, definition, pos, priority) VALUES (?, ?, ?, ?, ?)"
        var stmt: OpaquePointer?

        if sqlite3_prepare_v2(db, insertSQL, -1, &stmt, nil) == SQLITE_OK {
            for entry in seedEntries {
                sqlite3_bind_text(stmt, 1, (entry.0 as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 2, (entry.1 as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 3, (entry.2 as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 4, (entry.3 as NSString).utf8String, -1, nil)
                sqlite3_bind_int(stmt, 5, 9999)
                sqlite3_step(stmt)
                sqlite3_reset(stmt)
                sqlite3_clear_bindings(stmt)
            }
            sqlite3_finalize(stmt)
        }
    }

    // MARK: - Lookups

    /// Look up a word by its surface form or base form
    func lookup(word: String) -> [DictionaryEntry] {
        guard let db else { return [] }
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let query = """
        SELECT kanji, reading, definition, pos
        FROM entries
        WHERE kanji = ? OR reading = ?
        ORDER BY CASE WHEN kanji = ? THEN 0 ELSE 1 END, priority ASC, LENGTH(kanji) ASC
        LIMIT 10
        """
        var stmt: OpaquePointer?
        var results: [DictionaryEntry] = []
        var seenKeys: Set<String> = []

        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else { return [] }

        sqlite3_bind_text(stmt, 1, (trimmed as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 2, (trimmed as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 3, (trimmed as NSString).utf8String, -1, nil)

        while sqlite3_step(stmt) == SQLITE_ROW {
            let kanji = sqlite3_column_text(stmt, 0).map(String.init(cString:)) ?? ""
            let reading = sqlite3_column_text(stmt, 1).map(String.init(cString:)) ?? ""
            let definition = sqlite3_column_text(stmt, 2).map(String.init(cString:)) ?? ""
            let pos = sqlite3_column_text(stmt, 3).map(String.init(cString:)) ?? ""

            guard !kanji.isEmpty else { continue }
            let dedupeKey = [kanji, reading, definition, pos].joined(separator: "\u{1F}")
            guard seenKeys.insert(dedupeKey).inserted else { continue }

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

            if let entry = lookupEntries(for: token).first {
                enriched.definitions = entry.definitions

                let dictionaryPOS = PartOfSpeech(dictionaryPOS: entry.partOfSpeech)
                if dictionaryPOS != .unknown &&
                    (enriched.partOfSpeech == .unknown ||
                     enriched.partOfSpeech == .other ||
                     (enriched.partOfSpeech == .iAdjective && dictionaryPOS == .naAdjective)) {
                    enriched.partOfSpeech = dictionaryPOS
                }
            }

            return enriched
        }
    }

    /// Enrich tokens that still lack definitions using the Translation framework
    func enrichTokensWithTranslation(_ tokens: [Token], session: TranslationSession) async -> [Token] {
        var result = tokens

        // Collect indices of tokens missing definitions (skip particles/symbols)
        var toTranslate: [(index: Int, text: String)] = []
        for (i, token) in tokens.enumerated() {
            if token.definitions.isEmpty &&
               token.partOfSpeech != .symbol &&
               token.partOfSpeech != .filler &&
               !token.baseForm.isEmpty {
                toTranslate.append((i, token.baseForm))
            }
        }

        guard !toTranslate.isEmpty else { return result }

        // Batch translate using Translation framework
        let requests = toTranslate.map {
            TranslationSession.Request(sourceText: $0.text)
        }

        do {
            nonisolated(unsafe) let s = session
            let responses = try await s.translations(from: requests)
            for (j, response) in responses.enumerated() {
                let idx = toTranslate[j].index
                let translated = response.targetText
                // Only set if the translation differs from the input (avoids echoed Japanese)
                if translated != toTranslate[j].text {
                    result[idx].definitions = [translated]
                }
            }
        } catch {
            // Translation unavailable — leave definitions empty
        }

        return result
    }

    private func lookupEntries(for token: Token) -> [DictionaryEntry] {
        let candidates = [token.baseForm, token.surface, token.reading]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var seen: Set<String> = []
        for candidate in candidates where seen.insert(candidate).inserted {
            let matches = lookup(word: candidate)
            if !matches.isEmpty {
                return matches
            }
        }

        return []
    }
}
