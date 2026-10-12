# WebView and future JavaScript integration

The existing legal viewer uses `AppWebViewController`. `LegalWebViewController` supplies the title and document URL. All existing consent, authentication and settings entry points remain unchanged.

## Current scope

- UIKit + WKWebView, ephemeral website storage, loading/error/retry UI, in-app navigation and close action.
- Optional `AppJavaScriptBridge` with Promise replies via `WKScriptMessageHandlerWithReply`.
- Production legal documents have no enabled bridge or native methods. A document-provider domain is not an application trust boundary.
- No account tokens, profile data, payments, media permissions or native business operations are exposed or injected.
- This is an extension point, not completed integration with a business H5 application.

## Proposed version 1 contract

No external H5 contract has been provided. The following local contract can be adapted when that contract is available.

A future owned HTTPS page may call:

```javascript
try {
  const result = await window.webkit.messageHandlers.madeRoom.postMessage({
    version: 1,
    method: "methodRegisteredByNative",
    params: { text: "Example input" }
  });
  // result is the JSON object returned by the registered native method.
} catch (error) {
  // Handle a rejected native call. Do not assume success.
}
```

The channel exists only when native code supplies both an explicit origin allowlist and a nonempty method map. The application currently supplies neither. Do not enable it for the Google Docs legal pages.

Only main-frame messages from an exact HTTPS host and effective port are accepted, and the message origin must match the WebView's current origin. Redirecting to another origin removes permission to invoke methods even if that page remains viewable. Subframes, HTTP origins and host suffix lookalikes are rejected before routing.

Messages contain exactly `version`, `method`, and `params`; `params` and successful results are JSON objects. Message and result JSON are limited to 64 KiB. Method names are limited to 64 UTF-8 bytes. Unknown methods reject the Promise. Failure codes are `UNTRUSTED_ORIGIN`, `INVALID_MESSAGE`, `UNSUPPORTED_METHOD`, `INVALID_RESULT`, and `NATIVE_ERROR`; internal native error details are not sent to JavaScript.

WebKit delivers the reply to the calling JavaScript context. The implementation does not interpolate parameters into executable JavaScript. No custom request-ID callback mechanism is needed for these Promise replies.

## Lifecycle and future work

The container removes the message handler when it is released. The bridge does not retain the controller or WebView. Future registered closures should capture owning controllers weakly.

Registered methods currently return synchronously and must remain short. Before adding network, authentication, payment or other asynchronous operations, extend the contract with cancellation, exactly-once completion and bounded timeouts, and test navigation/account changes during those operations. Native-initiated events and credential injection are not implemented.

When the future H5 URL and operations are known, provide their exact origins, message schema, required authorization, outputs and failure handling. Add real-page integration tests before enabling business methods. Keep third-party document pages unprivileged.

## Verification boundary

Unit coverage verifies exact origin/port matching, main-frame enforcement, malformed messages, unknown methods, JSON text round-tripping and default-disabled behavior. Existing legal viewer loading/error checks remain covered. Actual H5 JavaScript-to-native integration and real-device behavior still need verification with the future page.
