typedef struct {
    float4 m[4];        // member elements of the matrix
} mat4;

mat4 transpose(mat4 matrix);
mat4 transpose(mat4 matrix) {
    // read matrix into a float16 vector
    float16 x = (float16)( matrix.m[0], matrix.m[1], matrix.m[2], matrix.m[3] );
    float16 t;
    
    //transpose
    t.even = x.lo; t.odd = x.hi; x.even = t.lo; x.odd = t.hi;
    
    mat4 result;
    //write back
    result.m[0] = x.lo.lo; result.m[1] = x.lo.hi; result.m[2] = x.hi.lo; result.m[3] = x.hi.hi;
    return result;
}

float4 multiplyMatrixVector(mat4 matrix, float4 vector);
float4 multiplyMatrixVector(mat4 matrix, float4 vector) {
   // matrix = transpose(matrix);
    return
    matrix.m[0] * vector +
    matrix.m[1] * vector +
    matrix.m[2] * vector +
    matrix.m[3] * vector;

//    float4 result;
//    for (int i = 0; i < 4; i++) {
//        float total = 0;
//        for (int j = 0; j < 4; j++) {
//            total += matrix.m[i][j] * vector[j];
//        }
//        
//        result[i] = total;
//    }
//    return result;
}