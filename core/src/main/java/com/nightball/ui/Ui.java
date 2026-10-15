package com.nightball.ui;

import com.badlogic.gdx.Application;
import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.Input;
import com.badlogic.gdx.InputAdapter;
import com.badlogic.gdx.graphics.Color;
import com.badlogic.gdx.graphics.Texture;
import com.badlogic.gdx.graphics.g2d.BitmapFont;
import com.badlogic.gdx.graphics.g2d.GlyphLayout;
import com.badlogic.gdx.graphics.g2d.SpriteBatch;
import com.badlogic.gdx.graphics.glutils.ShapeRenderer;
import com.badlogic.gdx.math.Vector3;
import com.badlogic.gdx.utils.Align;
import com.badlogic.gdx.utils.Disposable;
import com.badlogic.gdx.utils.viewport.ExtendViewport;

/**
 * Minimal immediate-mode UI: call {@link #begin()} once per frame, then draw widgets. A widget
 * method returns true on the frame it is tapped. Layout uses a virtual 960x540 (or larger) screen.
 */
public final class Ui extends InputAdapter implements Disposable {
    public static final float MIN_WIDTH = 960f;
    public static final float MIN_HEIGHT = 540f;

    public static final Color BACKGROUND = new Color(0x1A2125FF);
    public static final Color PANEL = new Color(0x2B353BFF);
    public static final Color BUTTON = new Color(0x3E7D4FFF);
    public static final Color BUTTON_DISABLED = new Color(0x3A4247FF);
    public static final Color TEXT = new Color(0xF2F2F2FF);
    public static final Color MUTED = new Color(0x9AA5ABFF);
    public static final Color RED = new Color(0xE56E56FF);
    public static final Color BLUE = new Color(0x5689E5FF);

    /** Text that the user can edit. On phones tapping it opens the system keyboard dialog. */
    public static final class TextBox {
        public String value;
        final String title;
        final int maxLength;

        public TextBox(String title, String value, int maxLength) {
            this.title = title;
            this.value = value;
            this.maxLength = maxLength;
        }
    }

    public final ExtendViewport viewport = new ExtendViewport(MIN_WIDTH, MIN_HEIGHT);
    public final ShapeRenderer shapes = new ShapeRenderer();
    public final SpriteBatch batch = new SpriteBatch();
    public final BitmapFont font = new BitmapFont();
    private final GlyphLayout layout = new GlyphLayout();
    private final Vector3 touch = new Vector3();
    private boolean tapped;
    private TextBox focused;
    private boolean enterPressed;

    public Ui() {
        font.getRegion().getTexture().setFilter(Texture.TextureFilter.Linear, Texture.TextureFilter.Linear);
        font.setUseIntegerPositions(false);
    }

    public static boolean isTouchDevice() {
        Application.ApplicationType type = Gdx.app.getType();
        return type == Application.ApplicationType.Android || type == Application.ApplicationType.iOS;
    }

    public void resize(int width, int height) {
        viewport.update(width, height, true);
    }

    public void begin() {
        viewport.apply(true);
        shapes.setProjectionMatrix(viewport.getCamera().combined);
        batch.setProjectionMatrix(viewport.getCamera().combined);
        tapped = Gdx.input.justTouched();
        if (tapped) {
            viewport.unproject(touch.set(Gdx.input.getX(), Gdx.input.getY(), 0f));
            focused = null;
        }
    }

    public float width() {
        return viewport.getWorldWidth();
    }

    public float height() {
        return viewport.getWorldHeight();
    }

    /** Pointer position in UI coordinates. */
    public Vector3 pointer(int index, Vector3 out) {
        return viewport.unproject(out.set(Gdx.input.getX(index), Gdx.input.getY(index), 0f));
    }

    public void rect(float x, float y, float w, float h, Color color) {
        shapes.begin(ShapeRenderer.ShapeType.Filled);
        shapes.setColor(color);
        shapes.rect(x, y, w, h);
        shapes.end();
    }

    /** Draws text with its baseline area starting at y (top of the text box). */
    public void text(String text, float x, float y, float scale, Color color, int align) {
        font.getData().setScale(scale);
        font.setColor(color);
        batch.begin();
        font.draw(batch, text, x, y, 0f, align, false);
        batch.end();
    }

    /** Text centred vertically on y. */
    public void label(String text, float x, float y, float scale, Color color, int align) {
        font.getData().setScale(scale);
        layout.setText(font, text);
        text(text, x, y + layout.height / 2f, scale, color, align);
    }

    public boolean button(String text, float x, float y, float w, float h, boolean enabled) {
        boolean hit = tapped && enabled && contains(x, y, w, h);
        rect(x, y, w, h, enabled ? BUTTON : BUTTON_DISABLED);
        label(text, x + w / 2f, y + h / 2f, 1.5f, enabled ? TEXT : MUTED, Align.center);
        return hit;
    }

    /** A plain row that can be tapped, used for lists. */
    public boolean row(String text, float x, float y, float w, float h) {
        boolean hit = tapped && contains(x, y, w, h);
        rect(x, y, w, h, PANEL);
        label(text, x + 16f, y + h / 2f, 1.4f, TEXT, Align.left);
        return hit;
    }

    public void textBox(final TextBox box, float x, float y, float w, float h) {
        if (tapped && contains(x, y, w, h)) {
            if (isTouchDevice()) {
                Gdx.input.getTextInput(new Input.TextInputListener() {
                    @Override
                    public void input(String text) {
                        box.value = clean(text, box.maxLength);
                    }

                    @Override
                    public void canceled() {
                    }
                }, box.title, box.value, "");
            } else {
                focused = box;
            }
        }
        boolean editing = focused == box;
        rect(x, y, w, h, editing ? BUTTON_DISABLED : PANEL);
        label(box.title, x, y + h + 14f, 1.1f, MUTED, Align.left);
        boolean cursor = editing && (System.currentTimeMillis() / 500) % 2 == 0;
        label(box.value + (cursor ? "_" : ""), x + 12f, y + h / 2f, 1.5f, TEXT, Align.left);
    }

    /** True once after Enter was pressed in a focused text box (desktop). */
    public boolean consumeEnter() {
        boolean pressed = enterPressed;
        enterPressed = false;
        return pressed;
    }

    private boolean contains(float x, float y, float w, float h) {
        return touch.x >= x && touch.x <= x + w && touch.y >= y && touch.y <= y + h;
    }

    @Override
    public boolean keyTyped(char character) {
        if (focused == null) {
            return false;
        }
        if (character == '\b') {
            if (!focused.value.isEmpty()) {
                focused.value = focused.value.substring(0, focused.value.length() - 1);
            }
        } else if (character == '\r' || character == '\n') {
            focused = null;
            enterPressed = true;
        } else if (character >= ' ' && character != 127 && focused.value.length() < focused.maxLength) {
            focused.value = focused.value + character;
        }
        return true;
    }

    public boolean isEditingText() {
        return focused != null;
    }

    static String clean(String text, int maxLength) {
        String trimmed = text == null ? "" : text.trim();
        return trimmed.length() > maxLength ? trimmed.substring(0, maxLength) : trimmed;
    }

    @Override
    public void dispose() {
        shapes.dispose();
        batch.dispose();
        font.dispose();
    }
}
