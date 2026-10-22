import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

class RawPrintService {
  static List<String> listPrinters() {
    final printers = <String>[];
    Pointer<Uint32> pcbNeeded = calloc<Uint32>();
    Pointer<Uint32> pcReturned = calloc<Uint32>();

    try {
      int result = EnumPrinters(
        PRINTER_ENUM_LOCAL | PRINTER_ENUM_CONNECTIONS,
        nullptr,
        4,
        nullptr,
        0,
        pcbNeeded,
        pcReturned,
      );

      if (result == 0) {
        final needed = pcbNeeded.value;
        if (needed <= 0) return printers;

        final buffer = calloc<Uint8>(needed);
        try {
          result = EnumPrinters(
            PRINTER_ENUM_LOCAL | PRINTER_ENUM_CONNECTIONS,
            nullptr,
            4,
            buffer,
            needed,
            pcbNeeded,
            pcReturned,
          );

          if (result != 0) {
            final count = pcReturned.value;
            final ptr = buffer.cast<PRINTER_INFO_4>();
            for (int i = 0; i < count; i++) {
              final info = (ptr + i).ref;
              final name = info.pPrinterName.toDartString();
              if (name.isNotEmpty) {
                printers.add(name);
              }
            }
          }
        } finally {
          calloc.free(buffer);
        }
      }
    } finally {
      calloc.free(pcbNeeded);
      calloc.free(pcReturned);
    }

    return printers;
  }

  static String findThermalPrinter() {
    final printers = listPrinters();
    if (printers.isEmpty) {
      throw Exception('No hay impresoras instaladas en el sistema');
    }

    final keywords = [
      'EPSON',
      'TM-',
      'TICKET',
      'THERMAL',
      'ZEBRA',
      'STAR',
      'POS',
      'RECEIPT',
      'BEMATECH',
      'DARUMA',
    ];

    for (final keyword in keywords) {
      final matches =
          printers.where((p) => p.toUpperCase().contains(keyword)).toList();
      if (matches.isNotEmpty) return matches.first;
    }

    return printers.first;
  }

  static void printRaw(String printerName, List<int> data) {
    final hPrinter = calloc<IntPtr>();

    Pointer<Utf16> pDatatype = 'RAW'.toNativeUtf16();
    Pointer<PRINTER_DEFAULTS> pDefaults = calloc<PRINTER_DEFAULTS>();
    Pointer<Utf16> pPrinterName = printerName.toNativeUtf16();

    try {
      pDefaults.ref.pDatatype = pDatatype;
      pDefaults.ref.pDevMode = nullptr;
      pDefaults.ref.DesiredAccess = PRINTER_ALL_ACCESS;

      int result = OpenPrinter(pPrinterName, hPrinter, pDefaults);
      if (result == 0) {
        throw Exception(
            'No se pudo abrir la impresora "$printerName". Código: ${GetLastError()}');
      }

      final printerHandle = hPrinter.value;

      try {
        Pointer<Utf16> docName = 'Ticket'.toNativeUtf16();
        Pointer<Utf16> outputFile = nullptr;
        Pointer<Utf16> dataType = 'RAW'.toNativeUtf16();

        final docInfo = calloc<DOC_INFO_1>();
        try {
          docInfo.ref.pDocName = docName;
          docInfo.ref.pOutputFile = outputFile;
          docInfo.ref.pDatatype = dataType;

          final jobId = StartDocPrinter(printerHandle, 1, docInfo);
          if (jobId == 0) {
            throw Exception(
                'Error al iniciar documento. Código: ${GetLastError()}');
          }

          try {
            result = StartPagePrinter(printerHandle);
            if (result == 0) {
              throw Exception(
                  'Error al iniciar página. Código: ${GetLastError()}');
            }

            try {
              final pWritten = calloc<Uint32>();
              final pBuffer = calloc<Uint8>(data.length);

              try {
                for (int i = 0; i < data.length; i++) {
                  pBuffer[i] = data[i];
                }

                result = WritePrinter(
                    printerHandle, pBuffer, data.length, pWritten);
                if (result == 0) {
                  throw Exception(
                      'Error al escribir en la impresora. Código: ${GetLastError()}');
                }

                if (pWritten.value != data.length) {
                  throw Exception(
                      'Solo se escribieron ${pWritten.value} de ${data.length} bytes');
                }
              } finally {
                calloc.free(pWritten);
                calloc.free(pBuffer);
              }
            } finally {
              EndPagePrinter(printerHandle);
            }
          } finally {
            EndDocPrinter(printerHandle);
          }
        } finally {
          calloc.free(docInfo);
          calloc.free(docName);
          calloc.free(dataType);
        }
      } finally {
        ClosePrinter(printerHandle);
      }
    } finally {
      calloc.free(hPrinter);
      calloc.free(pDatatype);
      calloc.free(pDefaults);
      calloc.free(pPrinterName);
    }
  }

  static int GetLastError() {
    return _GetLastError();
  }

  static final _GetLastError = DynamicLibrary.open('kernel32.dll')
      .lookupFunction<Int32 Function(), int Function()>('GetLastError');
}
