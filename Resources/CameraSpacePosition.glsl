
vec3 CalculateCameraSpacePositionFromWindow(float windowZ,
                                              vec3 cameraDirection,
                                              vec2 depthRange,
                                              vec3 matrixTerms) {
    float eyeZ = -matrixTerms.x / ((matrixTerms.y * windowZ) - matrixTerms.z);
    return cameraDirection * eyeZ;
}