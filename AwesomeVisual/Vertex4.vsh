attribute vec4 position;
attribute vec4 inputTextureCoordinate;
attribute vec4 inputTextureCoordinate2;

varying vec2 textureCoordinate;
varying vec2 textureCoordinate2;

const int GAUSSIAN_SAMPLES = 9;
varying vec2 blurCoordinates[GAUSSIAN_SAMPLES];
//uniform float texelWidthOffset=1; //半径
//uniform float texelHeightOffset=1;


float texelWidthOffset=1.0/640.0; //半径
float texelHeightOffset=1.0/640.0;

void main()
{
    gl_Position = position;
    textureCoordinate = inputTextureCoordinate.xy;
    textureCoordinate2 = inputTextureCoordinate2.xy;
    
    // Calculate the positions for the blur
    int multiplier = 0;
    vec2 blurStep;
    vec2 singleStepOffset = vec2(texelWidthOffset, texelHeightOffset);
    for (int i = 0; i < GAUSSIAN_SAMPLES; i++)
    {
        multiplier = (i - int(float(GAUSSIAN_SAMPLES - 1) / 2.0));
        // Blur in x (horizontal)
        blurStep = float(multiplier) * singleStepOffset;
        blurCoordinates[i] = textureCoordinate.xy + blurStep;
    }
}
