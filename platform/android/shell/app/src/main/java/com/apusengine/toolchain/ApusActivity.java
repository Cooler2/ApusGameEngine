package com.apusengine.toolchain;

import org.libsdl.app.SDLActivity;

public final class ApusActivity extends SDLActivity {
    @Override
    protected String[] getLibraries() {
        return new String[] { "SDL2", "apus_android_engine_probe", "main" };
    }
}
