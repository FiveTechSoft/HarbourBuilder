package com.harbour.builder;

import android.app.Activity;
import android.graphics.Color;
import android.os.Bundle;
import android.util.DisplayMetrics;
import android.util.TypedValue;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.EditText;
import android.widget.FrameLayout;
import android.widget.TextView;
import java.util.HashMap;

/**
 * HarbourBuilder Android GUI host.
 *
 * Instead of inflating an XML layout, the Activity exposes a set of methods
 * ({@link #createLabel}, {@link #createButton}, ...) that the native Harbour
 * backend invokes via JNI to build the UI programmatically.
 *
 * All coordinates received from Harbour are in form-designer pixels (1:1 with
 * Win32). We convert to device pixels using the display density so a 100 px
 * button looks the same on mdpi, hdpi and xxhdpi screens.
 */
public class MainActivity extends Activity {

    static { System.loadLibrary( "app" ); }

    private native void nativeInit();
    private native void nativeOnClick( int controlId );

    private FrameLayout root;
    private final HashMap< Integer, View > ctrls = new HashMap<>();
    private float density;   /* px multiplier: device px = form px * density */

    @Override
    protected void onCreate( Bundle savedInstanceState ) {
        super.onCreate( savedInstanceState );

        DisplayMetrics dm = getResources().getDisplayMetrics();
        density = dm.density;            /* 1.0 on mdpi, 2.0 on xhdpi, etc. */

        root = new FrameLayout( this );
        root.setBackgroundColor( Color.WHITE );
        setContentView( root,
                new ViewGroup.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT,
                        ViewGroup.LayoutParams.MATCH_PARENT ) );

        /* Run Harbour Main() - it will call createForm / createLabel / ...
           via JNI, which will post to the UI thread. */
        nativeInit();
    }

    /* Convert form pixels to device pixels. */
    private int dp( int formPx ) { return Math.round( formPx * density ); }

    private FrameLayout.LayoutParams lp( int x, int y, int w, int h ) {
        FrameLayout.LayoutParams p = new FrameLayout.LayoutParams( dp(w), dp(h) );
        p.leftMargin = dp(x);
        p.topMargin  = dp(y);
        return p;
    }

    /* ----- Called from JNI (native thread) ----- */

    public void createForm( final String title, int w, int h ) {
        runOnUiThread( new Runnable() { @Override public void run() {
            setTitle( title );
        }});
    }

    public void createLabel( final int id, final String text,
                             final int x, final int y, final int w, final int h ) {
        runOnUiThread( new Runnable() { @Override public void run() {
            TextView v = new TextView( MainActivity.this );
            v.setText( text );
            v.setTextSize( TypedValue.COMPLEX_UNIT_SP, 14 );
            v.setTextColor( Color.BLACK );
            root.addView( v, lp( x, y, w, h ) );
            ctrls.put( id, v );
        }});
    }

    public void createButton( final int id, final String text,
                              final int x, final int y, final int w, final int h ) {
        runOnUiThread( new Runnable() { @Override public void run() {
            Button b = new Button( MainActivity.this );
            b.setText( text );
            b.setAllCaps( false );
            b.setOnClickListener( new View.OnClickListener() {
                @Override public void onClick( View v ) { nativeOnClick( id ); }
            });
            root.addView( b, lp( x, y, w, h ) );
            ctrls.put( id, b );
        }});
    }

    public void createEdit( final int id, final String text,
                            final int x, final int y, final int w, final int h ) {
        runOnUiThread( new Runnable() { @Override public void run() {
            EditText e = new EditText( MainActivity.this );
            e.setText( text );
            e.setSingleLine( true );
            root.addView( e, lp( x, y, w, h ) );
            ctrls.put( id, e );
        }});
    }

    public void setCtrlText( final int id, final String text ) {
        runOnUiThread( new Runnable() { @Override public void run() {
            View v = ctrls.get( id );
            if( v instanceof TextView ) ( (TextView) v ).setText( text );
        }});
    }

    /** Must block until the UI thread answers - JNI caller expects a value. */
    public String getCtrlText( int id ) {
        View v = ctrls.get( id );
        if( v instanceof TextView ) return ( (TextView) v ).getText().toString();
        return "";
    }
}
