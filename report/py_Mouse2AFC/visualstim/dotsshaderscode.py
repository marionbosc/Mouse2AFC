# Copied from PsychtoolBox's SCREENDrawDots.c:
# https://github.com/Psychtoolbox-3/Psychtoolbox-3/blob/master/PsychSourceGL/Source/Common/Screen/SCREENDrawDots.c


PointSmoothFragmentShaderSrc = b"""
#version 120
uniform int drawRoundDots;
varying vec4 unclampedFragColor;
varying float pointSize;

void main()
{
    /* Non-round, aliased square dots requested? */
    if (drawRoundDots == 0) {
       /* Yes. Simply passthrough unclamped color and be done: */
       gl_FragColor = unclampedFragColor;
       return;
    }

    /* Passthrough RGB color values: */
    gl_FragColor.rgb = unclampedFragColor.rgb;

    /* Adapt alpha value dependent on relative radius of the fragment within a dot:   */
    /* This for point smoothing on GPU's that don't support this themselves.          */
    /* Points on the border of the dot, at [radius - 0.5 ; radius + 0.5] pixels, will */
    /* get their alpha value reduced from 1.0 * alpha to 0.0, so they completely      */
    /* disappear over a distance of 1 pixel distance unit. The - 1.0 subtraction      */
    /* in clamp() accounts for the fact that pointSize is 2.0 pixels larger than user */
    /* code requested. This 1 pixel padding around true size avoids cutoff artifacts. */
    float r = length(gl_TexCoord[1].st - vec2(0.5, 0.5)) * pointSize;
    r = 1.0 - clamp(r - (0.5 * pointSize - 1.0 - 0.5), 0.0, 1.0);
    gl_FragColor.a = unclampedFragColor.a * r;
    if (r <= 0.0)
        discard;
}
"""

PointSmoothVertexShaderSrc = b"""
#version 120
/* Vertex shader: Emulates fixed function pipeline, but in HDR color mode passes    */
/* gl_MultiTexCoord0 as varying unclampedFragColor to circumvent vertex color       */
/* clamping on gfx-hardware / OS combos that don't support unclamped operation:     */
/* PTBs color handling is expected to pass the vertex color in gl_MultiTexCoord0    */
/* for unclamped drawing for this reason in unclamped color mode. gl_MultiTexCoord2 */
/* delivers individual point size (diameter) information for each point.            */

uniform int useUnclampedFragColor;
varying float pointSize;
varying vec4 unclampedFragColor;

void main()
{
    if (useUnclampedFragColor > 0) {
       /* Simply copy input unclamped RGBA pixel color into output varying color: */
       unclampedFragColor = gl_MultiTexCoord0;
    }
    else {
       /* Simply copy regular RGBA pixel color into output varying color: */
       unclampedFragColor = gl_Color;
    }

    /* Output position is the same as fixed function pipeline: */
    gl_Position = ftransform();

    /* Point size comes via texture coordinate set 2: Make diameter 2 pixels bigger    */
    /* than requested, to have some 1 pixel security margin around the dot, to avoid   */
    /* cutoff artifacts for the rendered point-sprite quad. Compensate in frag-shader. */
    pointSize = gl_MultiTexCoord2[0] + 2.0;
    gl_PointSize = pointSize;
}
"""
