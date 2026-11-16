# Scalar vs SIMD summary (N = 1024, C = A + B)

| Lanes | Scalar cycles | SIMD cycles | Cycle speed-up | Elements/cycle | Fmax (MHz) | SIMD time (us) | Throughput (M elem/s) | Time speed-up | LUT4 | FF | MULT18 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 4097 | 4097 | 1.00x | 0.250 | 65.0 | 63.0 | 16.3 | 1.00x | 2490 | 375 | 3 |
| 2 | 4097 | 2049 | 2.00x | 0.500 | 65.8 | 31.1 | 32.9 | 2.02x | 4400 | 695 | 6 |
| 4 | 4097 | 1025 | 4.00x | 0.999 | 60.8 | 16.8 | 60.8 | 3.74x | 9068 | 1335 | 12 |
| 8 | 4097 | 513 | 7.99x | 1.996 | 54.4 | 9.4 | 108.5 | 6.67x | 19526 | 2615 | 24 |

Scalar reference time uses the 1-lane Fmax. Fmax/area: Yosys + nextpnr-ecp5 (Lattice ECP5-85k model), not Vivado/Quartus.
