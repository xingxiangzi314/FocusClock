package com.shiguang.focus;

/** Geometry follows the approved 906 x 674 reference card, in widget dp. */
final class HeatmapReferenceLayout {
    final float width, height, padX, padTop, padBottom, gapX, gapY;
    final float title, number, unit, weekday, day, cellHeight;
    final boolean compact;
    HeatmapReferenceLayout(int requestedWidth, int requestedHeight, int weeks) {
        width = requestedWidth > 0 ? requestedWidth : 220;
        height = requestedHeight > 0 ? requestedHeight : 164;
        float sx = width / 906f, sy = height / 674f, font = Math.min(sx,sy);
        gapX = Math.max(1,7.5f*sx);gapY = Math.max(1,8*sy);
        padX = 50.5f*sx;padTop = 52*sy;padBottom = 50*sy;
        cellHeight = (height-padTop-padBottom)*372/572/weeks - 2*gapY;
        compact = cellHeight < 12;
        title = Math.max(7.5f,46*font);number = Math.max(10,64*font);
        unit = Math.max(5,30*font);weekday = Math.max(6,35*font);
        day = Math.min(Math.max(5.5f,28*font),cellHeight*.8f);
    }
}
