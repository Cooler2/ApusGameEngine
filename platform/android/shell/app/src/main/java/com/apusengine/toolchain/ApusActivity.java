package com.apusengine.toolchain;

import android.app.AlertDialog;

import org.libsdl.app.SDLActivity;

import java.util.concurrent.atomic.AtomicBoolean;

public final class ApusActivity extends SDLActivity {
    private final AtomicBoolean errorDialogShowing = new AtomicBoolean(false);

    @Override
    protected String[] getLibraries() {
        return new String[] { "SDL2", "apus_android_engine_probe" };
    }

    /** Called from native engine threads. Never blocks the caller. */
    public void showErrorDialog(final String title, final String message) {
        runOnUiThread(() -> {
            if (isFinishing() || isDestroyed()) {
                return;
            }
            // A burst of failures must not create an unbounded dialog stack.
            if (!errorDialogShowing.compareAndSet(false, true)) {
                return;
            }

            new AlertDialog.Builder(this)
                .setTitle(title)
                .setMessage(message)
                .setCancelable(true)
                .setPositiveButton(android.R.string.ok, null)
                .setOnDismissListener(dialog -> errorDialogShowing.set(false))
                .show();
        });
    }
}
