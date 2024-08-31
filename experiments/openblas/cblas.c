#include <cblas.h>
#include <stdio.h>

void main() {
    // A = [1 -3]
    //     [2  4]
    //     [1 -2]
    double A[6] = { // Column major, (3, 2)
        1.0,2.0,1.0,
        -3.0,4.0,-1.0
    };

    // B = [1 -3]
    //     [2  4]
    //     [1 -2]
    double B[6] = { // Column major, (3, 2)
        1.0,2.0,1.0,
        -3.0,4.0,-1.0
    };

    // C = [0.5 0.5 0.5]
    //     [0.5 0.5 0.5]
    //     [0.5 0.5 0.5]
    double C[9] = { // Column major, (3, 3)
        .5,.5,.5,
        .5,.5,.5,
        .5,.5,.5
    };

    // cblas_     d                           ge                  mm
    // prefix     real, double precision      general matrix      matrix-matrix product

    // Computes formula: alpha * op(A) * op(B) + beta * C
    cblas_dgemm(
        CblasColMajor,  // Column/Row major     | A, B and C must have same convention
        CblasNoTrans,   // Don't transpose A    | op(A) = A
        CblasTrans,     // Transpose B          | op(B) = B^T
        3,              // M                    |
        3,              // N                    | A: (3, 2), B: (3, 2), C: (3, 3)
        2,              // K                    |
        1,              // alpha                | scaling of op(A) * op(B)
        A,              // A buffer             |
        3,              // lda                  | Leading dimensions of A
        B,              // B buffer             |
        3,              // ldb                  | Leading dimensions of B
        2,              // beta                 | scaling of C
        C,              // C buffer             |
        3               // ldc                  | Leading dimensions of C
    );

    // Result:
    // C = [11 -9  5]
    //     [-9 21 -1]
    //     [ 5 -1  3]
    for (int i = 0; i < 3; i++) {
        for (int j = 0; j < 3; j++) {
            printf("%lf ", C[i + j * 3]);
        }
        printf("\n");
    }
}