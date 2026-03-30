# Diagnostics & Debugging

The Dext Framework provides native, zero-allocation stack trace capture and asynchronous MAP file parsing to deliver production-ready, readable crash logs.

## The `Dext.Core.Debug.pas` Unit

By simply including the `Dext.Core.Debug` unit in your project, the Dext Framework automatically intercepts unhandled exceptions globally and generates a readable stack trace including **unit names**, **line numbers**, and **method definitions**. 

```pascal
program MyDextApp;

uses
  System.StartUpCopy,
  FMX.Forms,
  Dext.Core.Debug, // Enables automatic exception hooking
  MainForm in 'MainForm.pas' {Form1};
```

### Key Capabilities

1. **Zero-Allocation Ring Buffer:** Stack traces and exception pointers are captured in a pre-allocated fixed ring buffer. This guarantees that if your application crashes due to an `Out of Memory` (OOM) error, or heap corruption, Dext can still safely capture the stack trace without requesting additional heap memory.

2. **Asynchronous MAP File Parsing:** In order to resolve memory addresses (pointers) back to source code lines, Dext needs to read your executable's `.map` file. Since MAP files can be multiple megabytes in size, the framework delegates the parsing operation to a background `TAsyncTask`. This prevents your application or test suite from freezing on startup.

3. **Smart Wait:** If an exception is raised exactly while the background thread is still loading the `.map` file, the `TStackTrace` mechanism smartly waits (up to 3 seconds) for the parse to finish so it can output a useful, fully resolved stack frame, instead of falling back to hex addresses immediately.

4. **Correct RVA Alignment:** On the Delphi compiler targeting PE32/PE64 Windows formats, the `0001:` code segment requires an RVA correction block (-$1000). Dext's optimized parser automatically aligns NativeUInt pointers without requiring third-party libraries.

### Quick Example

To manually capture the current execution stack (e.g., inside a custom logger or metric block), simply call `TStackTrace.Capture`:

```pascal
uses
  Dext.Core.Debug;

procedure LogCriticalState;
begin
  Log.Error('System entered critical state! Stack: '#13#10 + TStackTrace.Capture(1));
end;
```

> **Note:** For the line numbers and unit names to appear correctly, you must compile your `.exe` / `.dll` with the "Detailed" Map File configuration enabled (`Project Options -> Building -> Delphi Compiler -> Linking -> Map file: Detailed`).
