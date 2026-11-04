/// Intervalos de sondeo del chat. Con el socket sano (ambos canales
/// conectados) el sondeo es solo un watchdog; sin él, el sondeo habitual.
Duration chatListPollEvery({required bool healthy}) =>
    Duration(seconds: healthy ? 120 : 20);

Duration chatThreadPollEvery({required bool healthy}) =>
    Duration(seconds: healthy ? 60 : 10);
