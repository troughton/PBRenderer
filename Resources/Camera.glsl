float computeEV100(float aperture, float shutterTime , float ISO) {
    // EV number is defined as:
    // 2^ EV_s = N^2 / t and EV_s = EV_100 + log2(S/100)
    // This gives
    // EV_s = log2(N^2 / t)
    // EV_100 + log2(S/100) = log2(N^2 / t)
    // EV_100 = log2(N^2 / t) - log2(S/100)
    // EV_100 = log2(N^2 / t . 100 / S)
    return log2(sqr(aperture) / shutterTime * 100 / ISO);
}

float computeEV100FromAvgLuminance(float avgLuminance) {
    // We later use the middle gray at 12.7% in order to have
    // a middle gray at 18% with a sqrt (2) room for specular highlights
    // But here we deal with the spot meter measuring the middle gray
    // which is fixed at 12.5 for matching standard camera
    // constructor settings (i.e. calibration constant K = 12.5)
    // Reference: http ://en.wikipedia.org/wiki/Film_speed
    return log2(avgLuminance * 100.0f / 12.5f);
}

float convertEV100ToExposure(float EV100) {
    // Compute the maximum luminance possible with H_sbs sensitivity
    // maxLum = 78 / ( S * q ) * N^2 / t
    // = 78 / ( S * q ) * 2^ EV_100
    // = 78 / (100 * 0.65) * 2^ EV_100
    // = 1.2 * 2^EV
    // Reference: http ://en.wikipedia.org/wiki/Film_speed
    float maxLuminance = 1.2f * pow (2.0f, EV100);
    return 1.0f / maxLuminance;
}

vec3 computeBloomLuminance(vec3 bloomColor, float bloomEC, float currentEV) {
    // currentEV is the value calculated at the previous frame
    float bloomEV = currentEV + bloomEC;
    // convert to luminance
    // See equation (12) for explanation about converting EV to luminance
    return bloomColor * pow(2.0f, bloomEV -3);
}

vec3 approximationSRGBToLinear(in vec3 sRGBCol) {
    return pow(sRGBCol , vec3(2.2));
}

vec3 approximationLinearToSRGB(in vec3 linearCol) {
    return pow(linearCol , vec3(1 / 2.2));
}

vec3 accurateSRGBToLinear(in vec3 sRGBCol) {
    vec3 linearRGBLo = sRGBCol / 12.92;
    vec3 linearRGBHi = pow(( sRGBCol + 0.055) / 1.055 , vec3(2.4));
    vec3 linearRGB = (sRGBCol.x <= 0.04045 && sRGBCol.y <= 0.04045 && sRGBCol.z <= 0.04045) ? linearRGBLo : linearRGBHi;
    return linearRGB;
}

vec3 accurateLinearToSRGB(in vec3 linearCol) {
    vec3 sRGBLo = linearCol * 12.92;
    vec3 sRGBHi = (pow(abs(linearCol), vec3(1.0/2.4)) * 1.055) - 0.055;
    vec3 sRGB = (linearCol.x <= 0.0031308 && linearCol.y <= 0.0031308 && linearCol.z <= 0.0031308) ? sRGBLo : sRGBHi;
    return sRGB;
}

//Should be applied in every lighting shader before writing the colour
vec3 epilogueLighting(vec3 color, float exposureMultiplier) {
    return color * exposureMultiplier;
}