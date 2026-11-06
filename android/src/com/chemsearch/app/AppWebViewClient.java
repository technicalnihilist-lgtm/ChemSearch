package com.chemsearch.app;

import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.webkit.WebResourceRequest;
import android.webkit.WebView;
import android.webkit.WebViewClient;

/**
 * Keeps our own bundled asset pages inside the WebView and hands every other
 * link (PubChem, PubMed, Google Patents, SDF/PNG downloads) to the system browser.
 */
public class AppWebViewClient extends WebViewClient {

    private final Context context;

    public AppWebViewClient(Context context) {
        this.context = context;
    }

    @Override
    public boolean shouldOverrideUrlLoading(WebView view, String url) {
        return openExternally(url);
    }

    @Override
    public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
        return openExternally(request.getUrl() == null ? null : request.getUrl().toString());
    }

    private boolean openExternally(String url) {
        if (url == null) return false;
        if (url.startsWith("file:///android_asset/")) return false;
        if (url.startsWith("about:")) return false;
        if (url.startsWith("javascript:")) return false;
        try {
            Intent i = new Intent(Intent.ACTION_VIEW, Uri.parse(url));
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            context.startActivity(i);
        } catch (Exception ignored) {
            // no browser installed — stay put
        }
        return true;
    }
}
