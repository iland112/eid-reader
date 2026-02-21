import 'dart:typed_data';

import 'package:dart_pcsc/dart_pcsc.dart';
import 'package:dmrtd/dmrtd.dart';
import 'package:logging/logging.dart';

/// [ComProvider] implementation for PC/SC USB smart card readers.
///
/// Wraps dart_pcsc's [Context] and [Card] for use with dmrtd's Passport API.
/// ISO 7816 APDU commands are identical over NFC and PC/SC, so dmrtd's
/// `Passport` class works transparently with this provider.
class PcscProvider extends ComProvider {
  static final _log = Logger('PcscProvider');

  final Duration timeout;
  final String? preferredReader;

  Context? _context;
  Card? _card;

  PcscProvider({
    this.timeout = const Duration(seconds: 30),
    this.preferredReader,
  }) : super(_log);

  /// Lists available PC/SC card readers.
  ///
  /// Returns an empty list if no readers are connected.
  static Future<List<String>> listReaders() async {
    final context = Context(Scope.user);
    try {
      await context.establish();
      return await context.listReaders();
    } finally {
      await context.release();
    }
  }

  @override
  Future<void> connect({
    Duration? timeout,
    String iosAlertMessage = '',
  }) async {
    if (isConnected()) return;

    try {
      _context = Context(Scope.user);
      await _context!.establish();

      final readers = await _context!.listReaders();
      if (readers.isEmpty) {
        throw NfcProviderError('No smart card reader found');
      }

      // Select reader: preferred > first available
      final reader = (preferredReader != null && readers.contains(preferredReader))
          ? preferredReader!
          : readers.first;

      _log.info('Using reader: $reader');

      // Wait for card insertion
      _log.fine('Waiting for card...');
      final readersWithCard =
          await _context!.waitForCard([reader]).value.timeout(
                timeout ?? this.timeout,
              );

      if (readersWithCard.isEmpty) {
        throw NfcProviderError('No card detected in reader');
      }

      // Connect to card (T=1 protocol for ISO 7816)
      _card = await _context!.connect(
        readersWithCard.first,
        ShareMode.shared,
        Protocol.any,
      );

      _log.info('Connected to card (protocol: ${_card!.activeProtocol})');
    } on Exception catch (e) {
      await disconnect();
      throw NfcProviderError.fromException(e);
    }
  }

  @override
  Future<void> disconnect({
    String? iosAlertMessage,
    String? iosErrorMessage,
  }) async {
    if (_card != null) {
      _log.fine('Disconnecting card');
      try {
        await _card!.disconnect(Disposition.resetCard);
      } catch (_) {}
      _card = null;
    }
    if (_context != null) {
      try {
        await _context!.release();
      } catch (_) {}
      _context = null;
    }
  }

  @override
  bool isConnected() => _card != null;

  @override
  Future<Uint8List> transceive(
    final Uint8List data, {
    Duration? timeout,
  }) async {
    if (_card == null) {
      throw NfcProviderError('Not connected to card');
    }
    try {
      return await _card!.transmit(data);
    } on Exception catch (e) {
      throw NfcProviderError.fromException(e);
    }
  }
}
