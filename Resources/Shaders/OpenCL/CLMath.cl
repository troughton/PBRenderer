float4 multiplyMatrixVector(float16 m, float4 vector);
float4 multiplyMatrixVector(float16 m, float4 vector) {
    
    float x = m.s0 * vector.x + m.s4 * vector.y + m.s8 * vector.z + m.sc * vector.w;
    float y = m.s1 * vector.x + m.s5 * vector.y + m.s9 * vector.z + m.sd * vector.w;
    float z = m.s2 * vector.x + m.s6 * vector.y + m.sa * vector.z + m.se * vector.w;
    float w = m.s3 * vector.x + m.s7 * vector.y + m.sb * vector.z + m.sf * vector.w;
    
    return (float4)(x, y, z, w);
}