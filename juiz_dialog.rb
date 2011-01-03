require 'rtranslate'
require 'yahooapis.rb'
require 'juiz_message.rb'
require 'kconv'
$KCODE = 'utf-8'

class Juizdialog
    # 計算に入れる単語の数
    SELECT_WORD = 4

    def initialize(status)
        @ydn = Yahooapis.new
        @jms = Juizmessage.new

        # 原材料
        @status = status
        @screen_name = status['user']['screen_name']
        @text = cleanup(status['text'])
        @text_length = @text.split(//u).length
        @time_zone = status['user']['time_zone']
        @orig_text = ''

        # 途中生成物
        @lang = 'ja'
        @words = []
        @money = 0
        @url = ''
        @showtext = true
        @showmoney = true

        # 最終生成物
        @juiz_suffix = ''
        @twit = ''
    end

    def gettext
        @text
    end
    def gettwit
        @twit
    end

    def dialog
        @jms.setinfo(@screen_name, @text)
        examlang()
        @jms.setlang(@lang, @time_zone)

        examprice()

        gendialog()
    end

    def gendialog
        ## Special Message
        # TODO: 既に100億使い切っている人 after summation
        if @text.match(/(今日|本日|きょう)の最高金額/) then
            # TODO after db
        elsif @text.match(/(今日|本日|きょう)の最低金額/) then
            # TODO after db
        elsif @text.match(/残(金|額|高|りの金額).*(いくら|教えて|わかる)/) then
            # TODO after db
        elsif @text.match(/(と|って|て)(言って|諭して)/) then
            # TODO

        ## Gourmet Message
        elsif (@text.match(/((なに|何)か).*(のみ|飲み)(もの|物).*(を|のみたい|飲みたい|ほしい|欲しい|ちょうだい|頂戴|お願い|おねがい)/) || @text.match(/(喉|のど).*(渇|乾|かわ)いた/)) then
            drink = @jms.gourmet_drink
            if @text.match(/(冷|つめ)たい/) then
                drink = @jms.gourmet_drink_cold
            elsif @text.match(/(あったか|あたた|温|暖)/) then
                drink = @jms.gourmet_drink_hot
            end
            @juiz_suffix = drink['message']
            @money = drink['money']
        elsif (@text.match(/((なに|何)か).*(たべ|食べ|食べる)(もの|物).*(を|たべたい|食べたい|ほしい|欲しい|ちょうだい|頂戴|お願い|おねがい)/) || @text.match(/(おなか|お腹|はら|腹).*(すいた|へった|減った)/)) then
            food = @jms.gourmet_food
            @juiz_suffix = food['message']
            @money = food['money']

        ## Seasonal Message
        elsif @text.match(/(あけ|明け)(おめ|オメ|御目)/) || @text.match(/(こと|コト)(よろ|ヨロ)/) || @text.match(/(今年|ことし).*(よろし|宜しく|ヨロシク|夜露)/) || @text.match(/(あけま|明けま).*(おめで|オメデ|お目出|御目出)/) || @text.match(/(昨年|去年).*(ありがと|有難|アリガト|お世話|世話)/) then
            if @text_length < 20 then
                @showmoney = false
            end
            @juiz_suffix = @jms.newyear
        elsif @text.match(/#tanzaku/)  || @text.match(/よ(う|ー)に(|。)$/) || @text.match(/短冊/) then
            @juiz_suffix = @jms.tanzaku

        ## Text Message
        elsif @text.match(/えっ(|？)$/) then
            @showmoney = false
            @juiz_suffix = @jms.text_extu
        elsif @text.match(/(だれ|誰)？(きみ|君)/) then
            @showmoney = false
            @juiz_suffix = 'あなたのコンシェルジュです。'+@jms.messia
        elsif @text.match(/誰(|.|..)？/) || @text.match(/誰だか知ってるの？/) then
            @showmoney = false
            @juiz_suffix = '誰か？誰かということはわかりかねますが。'
        elsif @text.match(/って知ってる？/) then
            @showmoney = false
            @juiz_suffix = 'いいえ。お調べいたしますか？'
        elsif @text.match(/たの？/) then
            @showmoney = false
            @juiz_suffix = '申し訳ありません。その後については、把握しておりません。'
        elsif @text.match(/ってこと？/) then
            @showmoney = false
            @juiz_suffix = 'はい。ありていに言えばそういうことです。'
        elsif @text.match(/(1|１|一)番(いい|良い).*頼む/) then
            @showmoney = false
            @juiz_suffix = 'Mr.Outside は言っています。ここでセレソンを諦めるべきではないと――'
        elsif @text.match(/(て|で)大丈夫か(\?|？|$)/) then
            @showmoney = false
            @juiz_suffix = '大丈夫です。きっと問題ありません。'
        elsif @text.match(/ジョニーを/) then
            if Kernel.rand(10) > 4 then
                @showmoney = false
                @juiz_suffix = 'ジョニー…をですか？'
            else
                @juiz_suffix = @jms.receive+@jms.messia
            end
        elsif @text.match(/もういいよ/) then
            @showmoney = false
            @juiz_suffix = '了解しました。Noblesse Oblige。'+@jms.messia
        elsif @text.match(/ありがと/) || @text.match(/(すば|素晴)らしい！/) || @text.match(/サンキュ/) then
            if @text_length < 18 then
                @showtext = false
                @showmoney = false
            end
            @juiz_suffix = @jms.text_thankyou
        elsif @text.match(/おめでとう/) && !@text.match(/おめでとう(」|って|と)/) then
            if @text_length < 18 then
                @showtext = false
                @showmoney = false
            end
            @juiz_suffix = @jms.text_congrats
        elsif @text.match(/残念(|.|..|...|....)$/) && @text_length < 10 then
            @showtext = false
            @showmoney = false
            @juiz_suffix = 'ご要望に沿えず、申し訳ございません…。'
        elsif @text.match(/(面白|おもしろ)かった(よ|！)/) then
            @showtext = false
            @showmoney = false
            @juiz_suffix = '楽しんでいただけてなによりです。Noblesse Oblige。'+@jms.messia
        elsif @text.match(/おはよ(う|ー)/) || @text.match(/おっはー/) || @text.match(/グッ.*モーニン/) then
            if @text_length < 18 then
                @showtext = false
                @showmoney = false
            end
            @juiz_suffix = @jms.text_morning
        elsif @text.match(/おやすみ/) then
            if @text_length < 18 then
                @showtext = false
                @showmoney = false
            end
            @juiz_suffix = @jms.text_sleep
        elsif @text.match(/こんばん(は|わ)/) then
            if @text_length < 18 then
                @showtext = false
                @showmoney = false
            end
            @juiz_suffix = 'こんばんは。'+@jms.messia
        elsif @text.match(/こんにち(は|わ)/) || @text.match(/ご(きげん|機嫌)よう/) then
            if @text_length < 18 then
                @showtext = false
                @showmoney = false
            end
            @juiz_suffix = 'はい、ジュイスです。'+@jms.messia
        elsif @text.match(/ただいま/) then
            @showtext = false
            @showmoney = false
            @juiz_suffix = 'お帰りになられたのですね。何かご要望はございますか？'
        elsif @text.match(/(行|い)って(き|来)ま/) then
            @showtext = false
            @showmoney = false
            @juiz_suffix = 'はい、お気をつけて。行ってらっしゃい！'
        elsif @text.match(/す(い|み)ません/) || @text.match(/(ゴメン|ごめん)(ネ|ね|なさい)/) then
            @juiz_suffix = @jms.text_sorry
            @money = Kernel.rand(10000)+10
        elsif @text.match(/お(つか|疲)れ(さん|さま|様|$)/) && @text_length < 13 then
            @showtext = false
            @showmoney = false
            @juiz_suffix = 'お気遣いありがとうございます。'+@jms.messia

        ## Normal Message
        elsif @words.length < 1 then
            @showtext = false
            @showmoney = false
            @juiz_suffix = @jms.noword(@text)
        elsif @text_length > 65 && !(@text.match(/この国には.*役回り/) || @text.match(/だって.*信じてくれた/)) then
            @showtext = false
            @showmoney = false
            @juiz_suffix = @jms.longtext
        elsif @money > 1000000000000 then
            @juiz_suffix = @jms.overmoney
        elsif @money > 10000000 then
            if @juiz_suffix == '' then
                @juiz_suffix = @jms.overmillion
            end
        elsif @money == 0 then
            @showtext = false
            @showmoney = false
            @juiz_suffix = @jms.zeromoney
        elsif @words.length == 1 && @url != '' && (wantto = @jms.wantto(@text)) != '' then
            @juiz_suffix = wantto+' '+@url
        else
            @juiz_suffix = @jms.receive+@jms.messia
        end

        ## Character Message
        if @screen_name == 'tachikomabot' then
            @showtext = false
            @showmoney = false
            @juiz_suffix = @jms.tachikomabot
        elsif @screen_name == '2G_bot' then
            @showtext = false
            @showmoney = false
            @juiz_suffix = @jms.no2(@text)
        elsif @screen_name == 'no_7_kaoru_bot' then
            @showtext = false
            @showmoney = false
            @juiz_suffix = @jms.no7(@text)
        elsif @screen_name == 'SELECAO_10' then
            @showtext = false
            @showmoney = false
            @juiz_suffix = @jms.no10
        end

        @jms.setmoney(@money)
        @twit = @jms.generate(@showtext, @showmoney, @juiz_suffix)
    end

    def examlang
        if @text.match(/^[0-9a-zA-Z !"#\$%&'()*+-.\/:;<=>?@\[\\\]^_`{\|}~]+$/) && !@text.match(/merry.*mas/i) then
            @lang = 'us'
            @orig_text = @text
            @text = Translate.t(@text, Language::ENGLISH, Language::JAPANESE)
        elsif (@time_zone == 'Beijing' || @time_zone == 'Hong Kong' || @time_zone == 'Chongqing' || @time_zone == 'Taipei') && !@text.match(/[ぁ-ん]/) then
            @lang = 'cn'
            @orig_text = @text
            @text = Translate.t(@text, Language::CHINESE, Language::JAPANESE)
        elsif @time_zone == 'Seoul' && !@text.match(/[ぁ-ん]/) then
            @lang = 'ko'
            @orig_text = @text
            @text = Translate.t(@text, Language::KOREAN, Language::JAPANESE)
        end
    end

    def examprice
        # ジュイスを抜く
        ext = @text.sub(/^(juiz|ジュイス|じゅいす)(\s|　|、|,|)/i, '')
        # 単語を抜き出す
        keywords = @ydn.keyphrase(ext)
        # 前から選ぶ
        @words = keywords[0,SELECT_WORD]
        @words.each do |word|
            if word.match(/[ !"#\$%&'()*+-.\/:;<=>?@\[\\\]^_`{\|}~]/) then
                next
            end
            if word == 'ジュイス' then
                next
            end
            pricebox = get_kakaku(word)
puts pricebox
            price = pricebox['price']
            if price != nil && price > 0 then
                @url = pricebox['url']
            else
                next
            end
            prand = rand(100)
            if @money == 0 then
                @money += price
            elsif price > 10 && prand > 85 then
                @money = @money * price
            elsif price > 100 && prand > 60 then
                @money = @money * (price / 10)
            elsif price > 1000 && prand > 40 then
                @money = @money * (price / 100)
            else
                @money += price
            end
        end
    end

    def get_kakaku(word)
        xml = @ydn.websearch(word, '1', 'kakaku')
        w = WebSearch.new
        w.parse(xml)

        yentourl = []
        yens = []

        w.list.each do |result|
            if result['summary'] != nil && result['summary'].match(/[0-9,]+円/) then
                k = result['summary'].sub(/^.*?([0-9,]+)円.*$/, '\1')
                k = k.sub(/,/, '')
                k_dec = k.to_i
                if k_dec > 0 then
                    yentourl[k_dec] = result['url']
                    yens.push(k_dec)
                end
            end
        end

        median = 0
        yens.sort!
        if yens.length > 0 then
            m = ((yens.length + 1) / 2).floor
            median = yens[m]
        end

        url = ''
        if median != nil && median > 0 then
            url = yentourl[median]
        end

        return {'word' => word, 'url' => url, 'price' => median}
    end

    def cleanup(text)
        # 最初にジュイスが出てくるか、文章になるまで回す
        ptext = ''
        while ptext != text
            if text.match(/^(\.@|@|＠)(flyeagle_echo|call_juiz|ジュイス)/) then
                break
            end
            ptext = text
            text = text.sub(/^[\s　\.]+/, '')
            text = text.sub(/^(@|＠)[a-zA-Z0-9_]+/, '')
            text = text.sub(/^[\s　\.]+/, '')
        end
        # もしジュイス宛ではなかったらfalse
        if !text.match(/^(\.@|@|＠)(flyeagle_echo|call_juiz|ジュイス)( |　|、|,|)/) then
            return nil
        end
        text = text.sub(/^(\.@|@|＠)(flyeagle_echo|call_juiz|ジュイス)( |　|、|,|)/, '')
        text = text.sub(/^[\s　]+/, '')
        text = text.sub(/[\s　]+$/, '')
        # フッタ処理
        text = text.sub(/\[.+\]$/, '')
        text = text.sub(/\*.+\*$/, '')
        # RT処理
        text = text.gsub(/RT @/, 'RT @ ')
        # URL処理
        uris = URI.extract(text)
        uris.each {|uri|
            text = text.sub(uri, '')
        }
        return text
    end
end
