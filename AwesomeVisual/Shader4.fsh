precision highp float;
uniform  sampler2D inputImageTexture;
varying  vec2 textureCoordinate;
varying  vec2 textureCoordinate2;


const lowp int GAUSSIAN_SAMPLES = 9;
varying vec2 blurCoordinates[GAUSSIAN_SAMPLES];
uniform sampler2D inputImageTexture2;//sucai29
uniform sampler2D inputImageTexture3;//sucai28
uniform sampler2D inputImageTexture4;//PSOverlay60
uniform sampler2D inputImageTexture5;//array
vec3 makeCurve(vec3 srcData,sampler2D mapData)
{
    vec3 dstData;
    dstData.r = texture2D(mapData,vec2(srcData.r,0.5)).r;
    dstData.g = texture2D(mapData,vec2(srcData.g,0.5)).g;
    dstData.b = texture2D(mapData,vec2(srcData.b,0.5)).b;
    return dstData;
}
vec3 overlayMap(vec3 srcData,sampler2D mapData,sampler2D blendData)
{
    vec3 dstData;
    vec4 blentex=texture2D(blendData,textureCoordinate);
    dstData.r = texture2D( mapData, vec2(blentex.r,srcData.r)).r;
    dstData.g = texture2D( mapData, vec2(blentex.g,srcData.g)).g;
    dstData.b = texture2D( mapData, vec2(blentex.b,srcData.b)).b;
    return dstData;
}


void main() {
    vec4 orgData=texture2D(inputImageTexture,textureCoordinate);
    lowp vec4 sum = vec4(0.0);
    sum += texture2D(inputImageTexture, blurCoordinates[0]) * 0.05;
    sum += texture2D(inputImageTexture, blurCoordinates[1]) * 0.09;
    sum += texture2D(inputImageTexture, blurCoordinates[2]) * 0.12;
    sum += texture2D(inputImageTexture, blurCoordinates[3]) * 0.15;
    sum += texture2D(inputImageTexture, blurCoordinates[4]) * 0.18;
    sum += texture2D(inputImageTexture, blurCoordinates[5]) * 0.15;
    sum += texture2D(inputImageTexture, blurCoordinates[6]) * 0.12;
    sum += texture2D(inputImageTexture, blurCoordinates[7]) * 0.09;
    sum += texture2D(inputImageTexture, blurCoordinates[8]) * 0.05;
    
    vec4 middleTex=texture2D(inputImageTexture2,textureCoordinate);
    vec3 mixData=mix(orgData.rgb,sum.rgb,middleTex.r);
    mixData=makeCurve(mixData,inputImageTexture5);
    orgData.rgb=overlayMap(mixData,inputImageTexture4,inputImageTexture3);
    gl_FragColor = orgData;
}
