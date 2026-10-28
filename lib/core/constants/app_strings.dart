/// Hand written, dependency free localization tables for GridPop.
///
/// English is the source language; Turkish is bundled as a second option.
/// `AppStrings.of(context).t('home.play')` resolves the active language.
library;

import 'package:flutter/widgets.dart';

/// Immutable view over one language table.
class AppStrings {
  AppStrings._(this.languageCode, this._values);

  /// Factory for the supported languages.
  factory AppStrings.ofLanguage(String languageCode) {
    final String normalized = languageCode.toLowerCase();
    if (normalized.startsWith('tr')) {
      return AppStrings._('tr', _tr);
    }
    return AppStrings._('en', _en);
  }

  final String languageCode;
  final Map<String, String> _values;

  /// All language codes shipped with the game.
  static const List<String> supportedLanguageCodes = <String>['en', 'tr'];

  /// Short month names, January first.
  ///
  /// Kept as one comma separated string instead of 12 keys so a date can be
  /// formatted without another lookup table.
  static const String _enMonths =
      'Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec';
  static const String _trMonths =
      'Oca,Şub,Mar,Nis,May,Haz,Tem,Ağu,Eyl,Eki,Kas,Ara';

  /// Display names shown in the settings screen.
  static String languageName(String code) {
    return code == 'tr' ? 'Türkçe' : 'English';
  }

  /// Looks up [key]. Unknown keys fall back to English and finally to the key
  /// itself, so a missing translation can never crash the UI.
  String t(String key) {
    final String? localized = _values[key];
    if (localized != null) {
      return localized;
    }
    return _en[key] ?? key;
  }

  /// Day and month in the active language, e.g. `28 Oct` / `28 Eki`.
  ///
  /// Dependency free on purpose: the game ships without `intl`, and a short
  /// "day month" label is all the daily card and the leaderboard need. The
  /// month name keeps its own casing, because Dart's `toUpperCase` turns a
  /// Turkish `i` into `I` rather than `İ`.
  String shortDate(DateTime date) {
    final List<String> months =
        (languageCode == 'tr' ? _trMonths : _enMonths).split(',');
    final int index = date.month.clamp(1, 12) - 1;
    return '${date.day} ${months[index]}';
  }

  /// Convenience shortcut used inside widgets.
  static AppStrings of(BuildContext context) {
    final AppLocalizations? holder =
        Localizations.of<AppLocalizations>(context, AppLocalizations);
    return holder?.strings ?? AppStrings.ofLanguage('en');
  }

  static const Map<String, String> _en = <String, String>{
    'app.name': 'GridPop',
    'app.tagline': 'Pop the grid. Chase the combo.',

    'common.play': 'Play',
    'common.back': 'Back',
    'common.close': 'Close',
    'common.cancel': 'Cancel',
    'common.ok': 'OK',
    'common.retry': 'Retry',
    'common.menu': 'Menu',
    'common.resume': 'Resume',
    'common.restart': 'Restart',
    'common.quit': 'Quit',
    'common.continue': 'Continue',
    'common.confirm': 'Confirm',
    'common.done': 'Done',
    'common.clear': 'Clear',
    'common.today': 'Today',
    'common.comingSoon': 'Coming soon',
    'common.on': 'On',
    'common.off': 'Off',

    'home.best': 'Best',
    'home.modesHint': 'Classic, time attack, zen and daily.',
    'home.leaderboardHint': 'Your best runs, mode by mode.',
    'home.statsHint': 'Everything you have played, counted.',
    'home.howToPlayHint': 'Rules, combos and the star goals.',
    'home.settingsHint': 'Sound, haptics, language and style.',
    'home.games': 'Games',
    'home.play': 'Play',
    'home.daily': 'Daily Challenge',
    'home.modes': 'Game Modes',
    'home.leaderboard': 'Leaderboard',
    'home.settings': 'Settings',
    'home.howToPlay': 'How To Play',
    'home.stats': 'Statistics',
    'home.shop': 'Shop',

    'modes.title': 'Game Modes',
    'modes.classic': 'Classic',
    'modes.classicDesc': 'Endless high score run. Play as long as you can.',
    'modes.daily': 'Daily Challenge',
    'modes.dailyDesc': 'Same board for everyone, once per day.',
    'modes.timeAttack': 'Time Attack',
    'modes.timeAttackDesc': '90 seconds. Maximum score, no mercy.',
    'modes.zen': 'Zen',
    'modes.zenDesc': 'No timer, no game over. Relax and clear.',
    'modes.dailyLocked': 'Come back after finishing today\'s challenge.',

    'game.score': 'Score',
    'game.best': 'Best',
    'game.combo': 'Combo',
    'game.time': 'Time',
    'game.pause': 'Pause',
    'game.rotate': 'Rotate',
    'game.hint': 'Hint',
    'game.noMoves': 'No space left for this piece!',
    'game.noMovesSoft': 'No space left - tray refreshed',
    'game.gameOver': 'Game Over',
    'game.paused': 'Paused',
    'game.newBest': 'New record!',
    'game.keepPlaying': 'Keep playing',
    'game.quitConfirm': 'Leave this run?',
    'game.quitMessage': 'Your progress in this run will be lost.',
    'game.pauseHint': 'Tap a piece to rotate it before dropping.',
    'game.mode': 'Mode',

    'daily.title': 'Daily Challenge',
    'daily.subtitle': 'One board. Everyone plays the same pieces.',
    'daily.playToday': "Play today's board",
    'daily.completed': 'Completed today',
    'daily.comesTomorrow': 'A new board arrives tomorrow.',
    'daily.yourBest': 'Your best',
    'daily.stars': 'Stars',
    'daily.streak': 'Streak',
    'daily.noRecord': 'No result yet',
    'daily.ladder': 'Streak rewards',
    'daily.ladderHint': 'Play on consecutive days to climb the ladder.',
    'daily.bonus': 'Bonus',

    'daily.progress': 'Score',

    'leaderboard.title': 'Leaderboard',
    'leaderboard.classic': 'Classic',
    'leaderboard.timeAttack': 'Time Attack',
    'leaderboard.zen': 'Zen',
    'leaderboard.daily': 'Daily',
    'leaderboard.empty': 'No scores yet. Be the first!',
    'leaderboard.local': 'Stored on this device',
    'leaderboard.rank': 'Rank',
    'leaderboard.score': 'Score',
    'leaderboard.date': 'Date',
    'leaderboard.cleared': 'Records cleared',
    'leaderboard.emptyHint':
        'Finish a run and your best scores land here.',
    'leaderboard.newRun': 'New',
    'leaderboard.linesShort': 'lines',

    'shop.title': 'Shop',
    'shop.subtitle': 'Power-ups for your next runs',
    'shop.coinsName': 'coins',
    'shop.buy': 'Buy',
    'shop.owned': 'Owned',
    'shop.notEnough': 'Not enough coins',
    'shop.bought': 'Added to your power-ups',
    'shop.watchAd': 'Watch ad',
    'shop.freeCoins': 'Out of coins?',
    'shop.freeCoinsDesc': 'Watch a short ad to earn 20 coins.',
    'shop.adTitle': 'Sponsored break',
    'shop.adBody': 'A quick break keeps GridPop free. Thanks for watching!',
    'shop.adNote': 'Demo ad: no real advertisement is shown yet.',
    'shop.adWaiting': 'Reward in',
    'shop.adClaim': 'Claim reward',

    'shopItem.refreshTray.name': 'Fresh blocks',
    'shopItem.refreshTray.desc': 'Swap your tray for brand new pieces.',
    'shopItem.clearBoard.name': 'Clear board',
    'shopItem.clearBoard.desc': 'Blast every block off the board.',
    'shopItem.booster.name': 'Score booster',
    'shopItem.booster.desc': 'Double points for 15 seconds.',
    'shopItem.hammer.name': 'Hammer',
    'shopItem.hammer.desc': 'Smash any single block on the board.',
    'shopItem.bomb.name': 'Bomb',
    'shopItem.bomb.desc': 'Blow a 3x3 hole anywhere on the board.',

    'power.refreshTray': 'Fresh',
    'power.clearBoard': 'Clear',
    'power.booster': 'Boost',
    'power.hammer': 'Hammer',
    'power.bomb': 'Bomb',
    'power.none': 'Out of stock - visit the shop',
    'power.aimHammer': 'Tap a block to smash it',
    'power.aimBomb': 'Tap a block to blow up the 3x3 around it',
    'power.aimCancel': 'Cancel',
    'power.noTarget': 'Tap a block, not an empty cell',

    'revive.title': 'One more chance?',
    'revive.body': 'Three rows were wiped clean and a fresh tray is waiting.',
    'revive.coins': 'Revive',
    'revive.ad': 'Watch ad',
    'revive.giveUp': 'Give up',
    'revive.used': 'Already used this run',

    'home.achievements': 'Achievements',

    'achievements.title': 'Achievements',
    'achievements.subtitle': 'Badges earned while playing. Unlock them all!',
    'achievements.tierBronze': 'Bronze',
    'achievements.tierSilver': 'Silver',
    'achievements.tierGold': 'Gold',
    'achievements.toast': 'Achievement unlocked!',

    'achievement.firstSteps.title': 'First Steps',
    'achievement.firstSteps.desc': 'Finish your first run.',
    'achievement.lineCook.title': 'Line Cook',
    'achievement.lineCook.desc': 'Clear your first line.',
    'achievement.comboStarter.title': 'Combo Starter',
    'achievement.comboStarter.desc': 'Reach a x3 combo.',
    'achievement.firstSpark.title': 'First Spark',
    'achievement.firstSpark.desc': 'Score a perfect move (three lines at once).',
    'achievement.risingStar.title': 'Rising Star',
    'achievement.risingStar.desc': 'Score 1,000 in a single run.',
    'achievement.brickLayer.title': 'Brick Layer',
    'achievement.brickLayer.desc': 'Place 1,000 cells.',
    'achievement.dailyDevotion.title': 'Daily Devotion',
    'achievement.dailyDevotion.desc': 'Complete a Daily Challenge.',
    'achievement.steady.title': 'Steady',
    'achievement.steady.desc': 'Play for 10 minutes in total.',
    'achievement.regular.title': 'Regular',
    'achievement.regular.desc': 'Finish 10 runs.',
    'achievement.carpenter.title': 'Carpenter',
    'achievement.carpenter.desc': 'Clear 100 lines.',
    'achievement.comboMaster.title': 'Combo Master',
    'achievement.comboMaster.desc': 'Reach a x8 combo.',
    'achievement.perfectionist.title': 'Perfectionist',
    'achievement.perfectionist.desc': 'Score 25 perfect moves.',
    'achievement.builder.title': 'Builder',
    'achievement.builder.desc': 'Place 5,000 cells.',
    'achievement.highRoller.title': 'High Roller',
    'achievement.highRoller.desc': 'Score 2,500 in a single run.',
    'achievement.blitz.title': 'Blitz',
    'achievement.blitz.desc': 'Score 1,500 in Time Attack.',
    'achievement.starCollector.title': 'Star Collector',
    'achievement.starCollector.desc': 'Earn 3 stars in a Daily Challenge.',
    'achievement.veteran.title': 'Veteran',
    'achievement.veteran.desc': 'Finish 50 runs.',
    'achievement.architect.title': 'Architect',
    'achievement.architect.desc': 'Clear 500 lines.',
    'achievement.grandBuilder.title': 'Grand Builder',
    'achievement.grandBuilder.desc': 'Place 15,000 cells.',
    'achievement.comboFrenzy.title': 'Combo Frenzy',
    'achievement.comboFrenzy.desc': 'Reach a x10 combo in a single run.',
    'achievement.gridLegend.title': 'Grid Legend',
    'achievement.gridLegend.desc': 'Score 5,000 in a single run.',
    'achievement.marathon.title': 'Marathon',
    'achievement.marathon.desc': 'Play for one hour in total.',

    'settings.title': 'Settings',
    'settings.game': 'Game',
    'settings.audio': 'Audio & Feedback',
    'settings.appearance': 'Appearance',
    'settings.language': 'Language',
    'settings.data': 'Data',
    'settings.sound': 'Sound effects',
    'settings.music': 'Music',
    'settings.vibration': 'Vibration',
    'settings.theme': 'Theme',
    'settings.themeSystem': 'System',
    'settings.themeLight': 'Light',
    'settings.themeDark': 'Dark',
    'settings.style': 'Visual style',
    'settings.styleHint': 'Swaps colours, blocks and stage decoration.',
    'settings.boardSize': 'Board size',

    'style.aurora': 'Aurora',
    'style.aurora.hint': 'Candy blocks on an indigo stage',
    'style.neon': 'Neon',
    'style.neon.hint': 'Arcade glow with a wire grid',
    'style.matte': 'Matte',
    'style.matte.hint': 'Soft pastel print, no shine',
    'style.retro': 'Retro',
    'style.retro.hint': 'Pixel blocks and CRT lines',
    'settings.showGhost': 'Placement preview',
    'settings.showHints': 'Hint button',
    'settings.resetProgress': 'Reset all progress',
    'settings.resetMessage': 'High score, statistics, records, coins, power-ups and achievements will be deleted.',
    'settings.resetDone': 'Progress cleared',
    'settings.about': 'About',
    'settings.version': 'Version',
    'settings.original': 'Original game, original art, no third party assets.',

    'how.title': 'How To Play',
    'how.subtitle': 'Everything you need, in about a minute.',
    'how.basics': 'Basics',
    'how.toolsSection': 'Tools and modes',
    'how.drag': 'Drag a piece from the tray onto the board.',
    'how.snap': 'Pieces snap to the grid. Release to lock them in.',
    'how.clear': 'Fill a whole row or column to clear it.',
    'how.multi': 'Clear several lines at once for a big bonus.',
    'how.combo': 'Clear lines in consecutive moves to grow the combo multiplier.',
    'how.rotate': 'Tap a piece to rotate it before you drop it.',
    'how.tools': 'Stuck? The hammer smashes one block, the bomb clears a 3x3 hole.',
    'how.revive': 'One second chance per run: wipe three rows and keep playing.',
    'how.over': 'The run ends when none of your remaining pieces fits.',
    'how.zen': 'Zen mode never ends: empty pieces are refilled for you.',
    'how.shapes': 'The shape library',
    'how.scoring': 'Scoring',

    'stats.title': 'Statistics',
    'stats.totalScore': 'Total score',
    'stats.gamesPlayed': 'Games played',
    'stats.bestCombo': 'Best combo',
    'stats.linesCleared': 'Lines cleared',
    'stats.perfectMoves': 'Perfect moves',
    'stats.cellsPlaced': 'Cells placed',
    'stats.playTime': 'Time played',
    'stats.averageScore': 'Average score',
    'stats.localOnly': 'Every number here is stored on this device.',
    'stats.emptyTitle': 'No runs yet',
    'stats.emptyHint': 'Play a round and your lifetime numbers land here.',

    'score.cells': 'Cells',
    'score.lines': 'Lines',
    'score.multi': 'Multi clear',
    'score.comboBonus': 'Combo',
    'score.perfect': 'Perfect',

    'combo.pop': 'Pop!',
    'combo.great': 'Great!',
    'combo.perfect': 'Perfect!',
    'combo.clean': 'Clean sweep!',

    'piece.dot': 'Dot',
    'piece.dom': 'Duo',
    'piece.riser': 'Riser',
    'piece.bar': 'Bar',
    'piece.stalk': 'Stalk',
    'piece.elbow': 'Elbow',
    'piece.rail': 'Rail',
    'piece.tower': 'Tower',
    'piece.block': 'Block',
    'piece.tee': 'Tee',
    'piece.zigzag': 'Zigzag',
    'piece.zigzagFlip': 'Zigzag flip',
    'piece.hook': 'Hook',
    'piece.beam': 'Beam',
    'piece.spire': 'Spire',
    'piece.teeLong': 'Wide tee',
    'piece.corner': 'Corner',
    'piece.terrace': 'Terrace',
    'piece.plus': 'Plus',
    'piece.crown': 'Crown',
    'piece.bolt': 'Bolt',
    'piece.fin': 'Fin',
    'piece.stairs': 'Stairs',
    'piece.gate': 'Gate',
    'piece.arrow': 'Arrow',
    'piece.monolith': 'Monolith',
    'piece.tile': 'Big tile',
  };

  static const Map<String, String> _tr = <String, String>{
    'app.name': 'GridPop',
    'app.tagline': 'Izgarayı patlat, kombo yakala.',

    'common.play': 'Oyna',
    'common.back': 'Geri',
    'common.close': 'Kapat',
    'common.cancel': 'Vazgeç',
    'common.ok': 'Tamam',
    'common.retry': 'Tekrar',
    'common.menu': 'Menü',
    'common.resume': 'Devam',
    'common.restart': 'Yeniden',
    'common.quit': 'Çık',
    'common.continue': 'Devam',
    'common.confirm': 'Onayla',
    'common.done': 'Bitti',
    'common.clear': 'Temizle',
    'common.today': 'Bugün',
    'common.comingSoon': 'Yakında',
    'common.on': 'Açık',
    'common.off': 'Kapalı',

    'home.best': 'Rekor',
    'home.modesHint': 'Klasik, zaman atlama, zen ve günlük.',
    'home.leaderboardHint': 'Her modda en iyi koşuların.',
    'home.statsHint': 'Oynadığın her şeyin sayımı.',
    'home.howToPlayHint': 'Kurallar, kombolar ve yıldız hedefleri.',
    'home.settingsHint': 'Ses, titreşim, dil ve stil.',
    'home.games': 'Oyun',
    'home.play': 'Oyna',
    'home.daily': 'Günlük Görev',
    'home.modes': 'Oyun Modları',
    'home.leaderboard': 'Sıralama',
    'home.settings': 'Ayarlar',
    'home.howToPlay': 'Nasıl Oynanır',
    'home.stats': 'İstatistik',
    'home.shop': 'Mağaza',

    'modes.title': 'Oyun Modları',
    'modes.classic': 'Classic',
    'modes.classicDesc': 'Sınırsız yüksek skor. Ne kadar dayanırsan o kadar.',
    'modes.daily': 'Günlük Görev',
    'modes.dailyDesc': 'Herkes için aynı tahta, günde bir kez.',
    'modes.timeAttack': 'Zaman Atlama',
    'modes.timeAttackDesc': '90 saniye. En yüksek skor, acımasız.',
    'modes.zen': 'Zen',
    'modes.zenDesc': 'Süre yok, oyun sonu yok. Rahatça temizle.',
    'modes.dailyLocked': 'Bugünkü görevi bitir, yarın tekrar gel.',

    'game.score': 'Skor',
    'game.best': 'Rekor',
    'game.combo': 'Kombo',
    'game.time': 'Süre',
    'game.pause': 'Duraklat',
    'game.rotate': 'Döndür',
    'game.hint': 'İpucu',
    'game.noMoves': 'Bu parça için yer kalmadı!',
    'game.noMovesSoft': 'Yer kalmadı - taşlar yenilendi',
    'game.gameOver': 'Oyun Bitti',
    'game.paused': 'Duraklatıldı',
    'game.newBest': 'Yeni rekor!',
    'game.keepPlaying': 'Devam et',
    'game.quitConfirm': 'Bu turdan çıkılsın mı?',
    'game.quitMessage': 'Bu turdaki ilerlemen kaybolacak.',
    'game.pauseHint': 'Parçaya dokunarak bırakmadan önce döndürebilirsin.',
    'game.mode': 'Mod',

    'daily.title': 'Günlük Görev',
    'daily.subtitle': 'Tek tahta. Herkes aynı parçaları oynuyor.',
    'daily.playToday': 'Bugünkü tahtayı oyna',
    'daily.completed': 'Bugün tamamlandı',
    'daily.comesTomorrow': 'Yeni tahta yarın geliyor.',
    'daily.yourBest': 'En iyin',
    'daily.stars': 'Yıldız',
    'daily.streak': 'Seri',
    'daily.noRecord': 'Henüz sonuç yok',
    'daily.ladder': 'Seri ödülleri',
    'daily.ladderHint': 'Üst üste günlerde oyna, merdiveni tırman.',
    'daily.bonus': 'Bonus',

    'daily.progress': 'Skor',

    'leaderboard.title': 'Sıralama',
    'leaderboard.classic': 'Classic',
    'leaderboard.timeAttack': 'Zaman Atlama',
    'leaderboard.zen': 'Zen',
    'leaderboard.daily': 'Günlük',
    'leaderboard.empty': 'Henüz skor yok. İlk sen ol!',
    'leaderboard.local': 'Bu cihazda saklanıyor',
    'leaderboard.rank': 'Sıra',
    'leaderboard.score': 'Skor',
    'leaderboard.date': 'Tarih',
    'leaderboard.cleared': 'Rekorlar silindi',
    'leaderboard.emptyHint':
        'Bir oyun bitir, en iyi skorların burada listelensin.',
    'leaderboard.newRun': 'Yeni',
    'leaderboard.linesShort': 'çizgi',

    'shop.title': 'Mağaza',
    'shop.subtitle': 'Sonraki oyunların için güçlendiriciler',
    'shop.coinsName': 'coin',
    'shop.buy': 'Satın al',
    'shop.owned': 'Stok',
    'shop.notEnough': 'Yetersiz coin',
    'shop.bought': 'Güçlendiricilerine eklendi',
    'shop.watchAd': 'Reklam izle',
    'shop.freeCoins': 'Coinin mi bitti?',
    'shop.freeCoinsDesc': 'Kısa bir reklam izle, 20 coin kazan.',
    'shop.adTitle': 'Sponsor arası',
    'shop.adBody': 'Kısa bir mola GridPop’u ücretsiz tutar. İzlediğin için teşekkürler!',
    'shop.adNote': 'Demo reklam: henüz gerçek reklam gösterilmiyor.',
    'shop.adWaiting': 'Ödüle kalan',
    'shop.adClaim': 'Ödülü al',

    'shopItem.refreshTray.name': 'Taze bloklar',
    'shopItem.refreshTray.desc': 'Taşlarını yepyeni parçalarla değiştir.',
    'shopItem.clearBoard.name': 'Tahtayı temizle',
    'shopItem.clearBoard.desc': 'Tahtadaki tüm blokları patlat.',
    'shopItem.booster.name': 'Puan artırıcı',
    'shopItem.booster.desc': '15 saniye boyunca 2x puan.',
    'shopItem.hammer.name': 'Çekiç',
    'shopItem.hammer.desc': 'Tahtadaki tek bir bloğu kır.',
    'shopItem.bomb.name': 'Bomba',
    'shopItem.bomb.desc': 'Tahtada 3x3’lük bir delik aç.',

    'power.refreshTray': 'Yenile',
    'power.clearBoard': 'Temizle',
    'power.booster': 'Boost',
    'power.hammer': 'Çekiç',
    'power.bomb': 'Bomba',
    'power.none': 'Stok bitti - mağazaya uğra',
    'power.aimHammer': 'Kırmak için bir bloğa dokun',
    'power.aimBomb': 'Etrafındaki 3x3’ü patlatmak için bir bloğa dokun',
    'power.aimCancel': 'Vazgeç',
    'power.noTarget': 'Boş hücreye değil, bir bloğa dokun',

    'revive.title': 'Bir şans daha?',
    'revive.body': 'Üç sıra temizlendi ve yeni taşlar hazır.',
    'revive.coins': 'Devam et',
    'revive.ad': 'Reklam izle',
    'revive.giveUp': 'Pes et',
    'revive.used': 'Bu oyunda zaten kullanıldı',

    'home.achievements': 'Başarımlar',

    'achievements.title': 'Başarımlar',
    'achievements.subtitle': 'Oynarken kazanılan rozetler. Hepsini topla!',
    'achievements.tierBronze': 'Bronz',
    'achievements.tierSilver': 'Gümüş',
    'achievements.tierGold': 'Altın',
    'achievements.toast': 'Başarım açıldı!',

    'achievement.firstSteps.title': 'İlk Adım',
    'achievement.firstSteps.desc': 'İlk oyununu tamamla.',
    'achievement.lineCook.title': 'Satır Ustası',
    'achievement.lineCook.desc': 'İlk satırını temizle.',
    'achievement.comboStarter.title': 'Kombo Başlangıcı',
    'achievement.comboStarter.desc': 'x3 komboya ulaş.',
    'achievement.firstSpark.title': 'İlk Kıvılcım',
    'achievement.firstSpark.desc': 'Mükemmel hamle yap (tek hamlede üç satır).',
    'achievement.risingStar.title': 'Yükselen Yıldız',
    'achievement.risingStar.desc': 'Tek oyunda 1.000 puan yap.',
    'achievement.brickLayer.title': 'Tuğla Ustası',
    'achievement.brickLayer.desc': '1.000 hücre yerleştir.',
    'achievement.dailyDevotion.title': 'Günlük Sadakat',
    'achievement.dailyDevotion.desc': 'Günlük Görev’i tamamla.',
    'achievement.steady.title': 'İstikrar',
    'achievement.steady.desc': 'Toplam 10 dakika oyna.',
    'achievement.regular.title': 'Müdavim',
    'achievement.regular.desc': '10 oyun tamamla.',
    'achievement.carpenter.title': 'Marangoz',
    'achievement.carpenter.desc': '100 satır temizle.',
    'achievement.comboMaster.title': 'Kombo Ustası',
    'achievement.comboMaster.desc': 'x8 komboya ulaş.',
    'achievement.perfectionist.title': 'Mükemmeliyetçi',
    'achievement.perfectionist.desc': '25 mükemmel hamle yap.',
    'achievement.builder.title': 'İnşaatçı',
    'achievement.builder.desc': '5.000 hücre yerleştir.',
    'achievement.highRoller.title': 'Büyük Vurgun',
    'achievement.highRoller.desc': 'Tek oyunda 2.500 puan yap.',
    'achievement.blitz.title': 'Yıldırım',
    'achievement.blitz.desc': 'Zaman Atlama’da 1.500 puan yap.',
    'achievement.starCollector.title': 'Yıldız Avcısı',
    'achievement.starCollector.desc': 'Günlük Görev’de 3 yıldız kazan.',
    'achievement.veteran.title': 'Kıdemli',
    'achievement.veteran.desc': '50 oyun tamamla.',
    'achievement.architect.title': 'Mimar',
    'achievement.architect.desc': '500 satır temizle.',
    'achievement.grandBuilder.title': 'Baş Mimar',
    'achievement.grandBuilder.desc': '15.000 hücre yerleştir.',
    'achievement.comboFrenzy.title': 'Kombo Çılgınlığı',
    'achievement.comboFrenzy.desc': 'Tek oyunda x10 komboya ulaş.',
    'achievement.gridLegend.title': 'Izgara Efsanesi',
    'achievement.gridLegend.desc': 'Tek oyunda 5.000 puan yap.',
    'achievement.marathon.title': 'Maraton',
    'achievement.marathon.desc': 'Toplam bir saat oyna.',

    'settings.title': 'Ayarlar',
    'settings.game': 'Oyun',
    'settings.audio': 'Ses ve Geri Bildirim',
    'settings.appearance': 'Görünüm',
    'settings.language': 'Dil',
    'settings.data': 'Veri',
    'settings.sound': 'Ses efektleri',
    'settings.music': 'Müzik',
    'settings.vibration': 'Titreşim',
    'settings.theme': 'Tema',
    'settings.themeSystem': 'Sistem',
    'settings.themeLight': 'Açık',
    'settings.themeDark': 'Koyu',
    'settings.style': 'Görsel stil',
    'settings.styleHint': 'Renkleri, blokları ve sahne dokusunu değiştirir.',
    'settings.boardSize': 'Tahta boyutu',

    'style.aurora': 'Aurora',
    'style.aurora.hint': 'İndigo sahnede şeker renkli bloklar',
    'style.neon': 'Neon',
    'style.neon.hint': 'Kablo ızgaralı arcade parıltısı',
    'style.matte': 'Mat',
    'style.matte.hint': 'Parlamasız, yumuşak pastel baskı',
    'style.retro': 'Retro',
    'style.retro.hint': 'Piksel bloklar ve CRT çizgileri',
    'settings.showGhost': 'Yerleştirme önizlemesi',
    'settings.showHints': 'İpucu butonu',
    'settings.resetProgress': 'Tüm ilerlemeyi sıfırla',
    'settings.resetMessage': 'Yüksek skor, istatistik, kayıtlar, coinler, güçlendiriciler ve başarımlar silinecek.',
    'settings.resetDone': 'İlerleme temizlendi',
    'settings.about': 'Hakkında',
    'settings.version': 'Sürüm',
    'settings.original': 'Özgün oyun, özgün görseller, üçüncü taraf varlık yok.',

    'how.title': 'Nasıl Oynanır',
    'how.subtitle': 'Bir dakikada öğreneceğin her şey.',
    'how.basics': 'Temeller',
    'how.toolsSection': 'Araçlar ve modlar',
    'how.drag': 'Tepeden bir parçayı sürükleyip tahtaya bırak.',
    'how.snap': 'Parçalar ızgaraya tam oturur. Bırakınca yerleşir.',
    'how.clear': 'Bir satırı veya sütunu tamamen doldur, temizlensin.',
    'how.multi': 'Aynı anda birden fazla çizgi temizle, büyük bonus kazan.',
    'how.combo': 'Üst üste temizlemeler yaparak kombo çarpanını büyüt.',
    'how.rotate': 'Parçaya dokunarak bırakmadan önce döndürebilirsin.',
    'how.tools': 'Sıkıştın mı? Çekiç tek bloğu kırar, bomba 3x3’lük delik açar.',
    'how.revive': 'Her oyunda bir ikinci şans: üç sıra temizlenir, oyun sürer.',
    'how.over': 'Kalan parçaların hiçbiri sığmazsa tur biter.',
    'how.zen': 'Zen modu bitmez: parçaların bittiğinde yenileri gelir.',
    'how.shapes': 'Parça kütüphanesi',
    'how.scoring': 'Puanlama',

    'stats.title': 'İstatistik',
    'stats.totalScore': 'Toplam skor',
    'stats.gamesPlayed': 'Oynanan oyun',
    'stats.bestCombo': 'En iyi kombo',
    'stats.linesCleared': 'Temizlenen çizgi',
    'stats.perfectMoves': 'Mükemmel hamle',
    'stats.cellsPlaced': 'Yerleştirilen hücre',
    'stats.playTime': 'Oynanan süre',
    'stats.averageScore': 'Ortalama skor',
    'stats.localOnly':
        'Buradaki her sayı yalnızca bu cihazda saklanır.',
    'stats.emptyTitle': 'Henüz oyun yok',
    'stats.emptyHint':
        'Bir tur oyna, tüm sayıların burada biriksin.',

    'score.cells': 'Hücre',
    'score.lines': 'Çizgi',
    'score.multi': 'Çoklu temizlik',
    'score.comboBonus': 'Kombo',
    'score.perfect': 'Mükemmel',

    'combo.pop': 'Pop!',
    'combo.great': 'Harika!',
    'combo.perfect': 'Mükemmel!',
    'combo.clean': 'Tam temizlik!',

    'piece.dot': 'Nokta',
    'piece.dom': 'Çift',
    'piece.riser': 'Dikme',
    'piece.bar': 'Çubuk',
    'piece.stalk': 'Sütun',
    'piece.elbow': 'Dirsek',
    'piece.rail': 'Ray',
    'piece.tower': 'Kule',
    'piece.block': 'Kare',
    'piece.tee': 'T',
    'piece.zigzag': 'Zigzag',
    'piece.zigzagFlip': 'Ters Zigzag',
    'piece.hook': 'Kanca',
    'piece.beam': 'Kiriş',
    'piece.spire': 'Kule5',
    'piece.teeLong': 'Geniş T',
    'piece.corner': 'Köşe',
    'piece.terrace': 'Teras',
    'piece.plus': 'Artı',
    'piece.crown': 'Taç',
    'piece.bolt': 'Yıldırım',
    'piece.fin': 'Yüzgeç',
    'piece.stairs': 'Merdiven',
    'piece.gate': 'Kapı',
    'piece.arrow': 'Ok',
    'piece.monolith': 'Anıt',
    'piece.tile': 'Büyük Kare',
  };
}

/// Minimal [Localizations] holder. Using our own delegate keeps the app free
/// of generated localization code and of extra dependencies.
class AppLocalizations {
  const AppLocalizations(this.strings);

  final AppStrings strings;

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('tr'),
  ];
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppStrings.supportedLanguageCodes.contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(AppStrings.ofLanguage(locale.languageCode));

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}