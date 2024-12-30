/* 
 * Solves the Panfilov model using an explicit numerical scheme.
 * Modified with MPI and OpenMP parallelization.
 * Updated to include cmdLine and splot functionality.
 */
#include <stdio.h>
#include <assert.h>
#include <stdlib.h>
#include <iostream>
#include <iomanip>
#include <string.h>
#include <math.h>
#include <sys/time.h>
#include <mpi.h>
#include <omp.h>
#include <fstream>
#include <sstream>

using namespace std;

#define NB 1
#define NC_B 2

// Timer utility
static const double kMicro = 1.0e-6;
double getTime() {
    struct timeval TV;
    struct timezone TZ;
    const int RC = gettimeofday(&TV, &TZ);
    if (RC == -1) {
        cerr << "ERROR: Bad call to gettimeofday" << endl;
        return (-1);
    }
    return (((double)TV.tv_sec) + kMicro * ((double)TV.tv_usec));
}

// Allocate a 2D array
double **alloc2D(int m, int n) {
    double **E;
    E = (double **)malloc(sizeof(double *) * m + sizeof(double) * n * m);
    assert(E);
    for (int j = 0; j < m; j++)
        E[j] = (double *)(E + m) + j * n;
    return (E);
}

// Reports statistics about the computation
double MPI_Stats(double **E, int m, int n, double *_mx, int *_size) {
    double mx = -1;
    double l2 = 0; // Sum of squares
    int size = m * n;
    for (int j = 1; j <= m; j++) {
        for (int i = 1; i <= n; i++) {
            l2 += E[j][i] * E[j][i];
            if (E[j][i] > mx)
                mx = E[j][i];
        }
    }
    *_mx = mx;
    *_size = size;
    return l2;
}

// Command line parser
void cmdLine(int argc, char *argv[], double &T, int &n, int &px, int &py, int &plot_freq, int &no_comm, int &num_threads) {
    T = 1000.0;
    n = 400;
    px = 1;
    py = 1;
    plot_freq = 0;
    no_comm = 0;
    num_threads = 1;

    for (int i = 1; i < argc; ++i) {
        if (strcmp(argv[i], "-t") == 0) {
            T = atof(argv[++i]);
        } else if (strcmp(argv[i], "-n") == 0) {
            n = atoi(argv[++i]);
        } else if (strcmp(argv[i], "-p") == 0) {
            plot_freq = atoi(argv[++i]);
        } else if (strcmp(argv[i], "-x") == 0) {
            px = atoi(argv[++i]);
        } else if (strcmp(argv[i], "-y") == 0) {
            py = atoi(argv[++i]);
        } else if (strcmp(argv[i], "-k") == 0) {
            no_comm = 1;
        } else if (strcmp(argv[i], "-o") == 0) {
            num_threads = atoi(argv[++i]);
        } else {
            cerr << "Unknown argument: " << argv[i] << endl;
            exit(EXIT_FAILURE);
        }
    }

    if (no_comm) {
        cout << "MPI communication is disabled (-k flag provided)." << endl;
    }
    cout << "Arguments parsed:" << endl;
    cout << "T = " << T << endl;
    cout << "n = " << n << endl;
    cout << "px = " << px << endl;
    cout << "py = " << py << endl;
    cout << "plot_freq = " << plot_freq << endl;
    cout << "num_threads = " << num_threads << endl;
}

// Plotting function using Gnuplot
void splot(double **E, double T, int niter, int m, int n) {
    std::string tempFileName = "temp_plot_data.dat";
    std::ofstream tempFile(tempFileName);

    if (!tempFile.is_open()) {
        std::cerr << "Error: Unable to open temporary file for plotting." << std::endl;
        return;
    }

    for (int j = 1; j <= m; ++j) {
        for (int i = 1; i <= n; ++i) {
            tempFile << i << " " << j << " " << E[j][i] << "\n";
        }
        tempFile << "\n";
    }
    tempFile.close();

    FILE *gnuplotPipe = popen("gnuplot", "w");
    if (!gnuplotPipe) {
        std::cerr << "Error: Unable to open Gnuplot pipe." << std::endl;
        return;
    }

    std::ostringstream gnuplotCommands;
    gnuplotCommands << "set title 'Excitation at Time " << T << " (Iteration " << niter << ")'\n";
    gnuplotCommands << "set xlabel 'X-axis'\n";
    gnuplotCommands << "set ylabel 'Y-axis'\n";
    gnuplotCommands << "set zlabel 'Excitation'\n";
    gnuplotCommands << "set xrange [1:" << n << "]\n";
    gnuplotCommands << "set yrange [1:" << m << "]\n";
    gnuplotCommands << "set pm3d\n";
    gnuplotCommands << "splot '" << tempFileName << "' with pm3d\n";

    fprintf(gnuplotPipe, "%s\n", gnuplotCommands.str().c_str());
    fflush(gnuplotPipe);

    std::cout << "Press Enter to close the plot..." << std::endl;
    getchar();

    pclose(gnuplotPipe);
    remove(tempFileName.c_str());
}

// Simulation function (stubbed for completeness)
void simulate (double** E,  double** E_prev,double** R,
		const double alpha, const int n_total, const int m_total, const double kk,
		const double dt, const double a, const double epsilon,
		const double M1,const double  M2, const double b,int n,int m, int px, int py){
	/*******************************************************************/
	double t = 0.0;
	int root = 0;
	int niter;
	int rank =0, np=1;
	int num_threads = 4;
	MPI_Comm_size(MPI_COMM_WORLD,&np);
	MPI_Comm_rank(MPI_COMM_WORLD,&rank);
	MPI_Request	send_request,recv_request;
	MPI_Request	send_request2,recv_request2;
	MPI_Request	send_requestc,recv_requestc;
	MPI_Request	send_request2c,recv_request2c;
	int plot_msgsiz = (m+1)*(n+1)*sizeof(double);
	int col_msgsiz = (m+1)*sizeof(double);
	double * sendbuffer = new double [m];
	double * recvbuffer = new double [m];
	double * sendbuffer2 = new double [m];
	double * recvbuffer2 = new double [m];
	double* submatrix = new double[(m+1)*(n+1)];
	double* revmatrix = new double[(m+2)*(n+2)];


	int i, j;
	/*
	 * Copy data from boundary of the computational box
	 * to the padding region, set up for differencing
	 * on the boundary of the computational box
	 * Using mirror boundaries
	 */
    #pragma omp parallel for num_threads(num_threads) private(i)
	for (i=1; i<=n; i++)
			E_prev[0][i] = E_prev[2][i];
		for (i=1; i<=n; i++)
			E_prev[m+1][i] = E_prev[m-1][i];

	#pragma omp parallel for num_threads(num_threads)private(j)
	for (j=1; j<=m; j++)
		E_prev[j][0] = E_prev[j][2];
	for (j=1; j<=m; j++)
		E_prev[j][n+1] = E_prev[j][n-1];


	// Solve for the excitation, a PDE
	int colid = rank % px; //column id
	int rowid = rank / px;//row id of the processes

	#pragma omp parallel for num_threads(num_threads)private(i)
	for (i=1; i<=n; i++) {
		E_prev[0][i] = E_prev[2][i];
		E_prev[m+1][i] = E_prev[m-1][i];
	}

	#pragma omp parallel for num_threads(num_threads)private(j)
	for (j=1; j<=m; j++){
		E_prev[j][0] = E_prev[j][2];
		E_prev[j][n+1] = E_prev[j][n-1];
	}


	if (py > 1) {

		if (rowid == 0) { //top
			//send a row of information
			MPI_Isend(&E_prev[m][1], n , MPI_DOUBLE, rank + px , NB, MPI_COMM_WORLD, &send_request);
			MPI_Irecv(&E_prev[m+1][1], n, MPI_DOUBLE, rank + px, NB, MPI_COMM_WORLD, &recv_request);
			MPI_Wait (&send_request,MPI_STATUS_IGNORE);
			MPI_Wait (&recv_request,MPI_STATUS_IGNORE);
		}

		else if (rowid == py-1) { //bottom

			MPI_Isend(&E_prev[1][1], n, MPI_DOUBLE, rank - px, NB, MPI_COMM_WORLD, &send_request);

			MPI_Irecv(&E_prev[0][1], n, MPI_DOUBLE, rank - px, NB, MPI_COMM_WORLD, &recv_request);
			MPI_Wait (&send_request,MPI_STATUS_IGNORE);
			MPI_Wait (&recv_request,MPI_STATUS_IGNORE);
		}
		else { //middle

			MPI_Isend(&E_prev[m][1], n , MPI_DOUBLE, rank + px , NB, MPI_COMM_WORLD, &send_request);

			MPI_Irecv(&E_prev[m+1][1], n, MPI_DOUBLE, rank + px, NB, MPI_COMM_WORLD, &recv_request);
			MPI_Wait (&send_request,MPI_STATUS_IGNORE);
			MPI_Wait (&recv_request,MPI_STATUS_IGNORE);

			MPI_Isend(&E_prev[1][1], n, MPI_DOUBLE, rank - px, NB, MPI_COMM_WORLD, &send_request);

			MPI_Irecv(&E_prev[0][1], n, MPI_DOUBLE, rank - px, NB, MPI_COMM_WORLD, &recv_request);
			MPI_Wait (&send_request,MPI_STATUS_IGNORE);
			MPI_Wait (&recv_request,MPI_STATUS_IGNORE);
		}
	}
	if (px > 1) {
		if (colid == 0) {
			for (int j=1; j<=m; j++){
				sendbuffer[j-1] = E_prev[j][n];
			}

			MPI_Isend(&sendbuffer[0], m, MPI_DOUBLE,rank+1,NC_B, MPI_COMM_WORLD, &send_requestc);
			MPI_Irecv(&recvbuffer[0], m, MPI_DOUBLE, rank+1,NC_B, MPI_COMM_WORLD, &recv_requestc);

			MPI_Wait (&recv_requestc,MPI_STATUS_IGNORE);
			for (int j=1;j<=m;j++) {
				E_prev[j][n+1] = recvbuffer[j-1];
			}
			MPI_Wait (&send_requestc,MPI_STATUS_IGNORE);
		}
		// Rightmost
		if (colid == px-1) { 	// Packing to send left

			for (int j=1; j<=m; j++){
				sendbuffer[j-1] = E_prev[j][1];

			}

			MPI_Isend(&sendbuffer[0], m, MPI_DOUBLE,rank-1,NC_B, MPI_COMM_WORLD, &send_requestc);
			MPI_Irecv(&recvbuffer[0], m, MPI_DOUBLE, rank-1,NC_B, MPI_COMM_WORLD, &recv_requestc);


			MPI_Wait (&recv_requestc,MPI_STATUS_IGNORE);

			#pragma omp parallel for num_threads(num_threads) private(j)
			for (int j=1; j<=m; j++){
				E_prev[j][0] = recvbuffer[j-1];
			}
			MPI_Wait (&send_requestc,MPI_STATUS_IGNORE);
		}
		// at the middle
		if (colid>0 && colid <px-1)  {

			for (int j=1; j<=m; j++){
				// Packing to send right
				sendbuffer[j-1] = E_prev[j][n];
				// Packing to send left
				sendbuffer2[j-1] = E_prev[j][1];
			}
			MPI_Isend(&sendbuffer[0], m, MPI_DOUBLE,rank+1,NC_B, MPI_COMM_WORLD, &send_requestc);
			MPI_Irecv(&recvbuffer[0], m, MPI_DOUBLE, rank+1,NC_B, MPI_COMM_WORLD, &recv_requestc);
			// Recieve packed array
			MPI_Wait (&recv_requestc,MPI_STATUS_IGNORE);

			MPI_Wait (&send_requestc,MPI_STATUS_IGNORE);


			MPI_Isend(&sendbuffer2[0], m, MPI_DOUBLE,rank-1,NC_B, MPI_COMM_WORLD, &send_request2c);

			MPI_Irecv(&recvbuffer2[0], m, MPI_DOUBLE, rank-1,NC_B, MPI_COMM_WORLD, &recv_request2c);

			MPI_Wait (&recv_request2c,MPI_STATUS_IGNORE);
			// Recieve packed array
			for (int j=1; j<=m; j++){
				E_prev[j][n+1] = recvbuffer[j-1];
				E_prev[j][0] = recvbuffer2[j-1];
			}
			MPI_Wait (&send_request2c,MPI_STATUS_IGNORE);
		}

	}
	/***********************************/
	// Solve for the excitation, the PD

	for (j=1; j<=m; j++){
		for (i=1; i<=n; i++) {
			E[j][i] = E_prev[j][i]+alpha*(E_prev[j][i+1]+E_prev[j][i-1]-4*E_prev[j][i]+E_prev[j+1][i]+E_prev[j-1][i]);
		}
	}

	/*
	 * Solve the ODE, advancing excitation and recovery to the
	 *     next timtestep
	 */
	for (j=1; j<=m; j++){
		for (i=1; i<=n; i++)
			E[j][i] = E[j][i] -dt*(kk* E[j][i]*(E[j][i] - a)*(E[j][i]-1)+ E[j][i] *R[j][i]);
	}

	for (j=1; j<=m; j++){
		for (i=1; i<=n; i++)
			R[j][i] = R[j][i] + dt*(epsilon+M1* R[j][i]/( E[j][i]+M2))*(-R[j][i]-kk* E[j][i]*(E[j][i]-b-1));
	}

}

int main(int argc, char **argv) {
    double **E, **R, **E_prev;
    const double a = 0.1, b = 0.1, kk = 8.0, M1 = 0.07, M2 = 0.3, epsilon = 0.01, d = 5e-5;

    double T = 1000.0;
    int m = 200, n = 200, px = 1, py = 1, plot_freq = 0, no_comm = 0, num_threads = 1;

    cmdLine(argc, argv, T, n, px, py, plot_freq, no_comm, num_threads);
    m = n;

    MPI_Init(&argc, &argv);
    int myrank, nprocs;
    MPI_Comm_rank(MPI_COMM_WORLD, &myrank);
    MPI_Comm_size(MPI_COMM_WORLD, &nprocs);

    if (myrank == 0) {
        printf("Number of processes: %d\n", nprocs);
    }

    int row = m / py + (myrank / px == py - 1 ? m % py : 0);
    int col = n / px + (myrank % px == px - 1 ? n % px : 0);

    E = alloc2D(row + 2, col + 2);
    E_prev = alloc2D(row + 2, col + 2);
    R = alloc2D(row + 2, col + 2);

    for (int j = 1; j <= row; ++j)
        for (int i = 1; i <= col; ++i)
            E_prev[j][i] = R[j][i] = 0;

    double dt = 0.1; // Calculate based on inputs
    double alpha = d * dt / (1.0 / n * 1.0 / n);

    double t = 0.0;
    int niter = 0;

    while (t < T) {
        t += dt;
        niter++;
        simulate(E, E_prev, R, alpha, n, m, kk, dt, a, epsilon, M1, M2, b, col, row, px, py);
        MPI_Barrier(MPI_COMM_WORLD);

        double **tmp = E;
        E = E_prev;
        E_prev = tmp;

        if (plot_freq && myrank == 0 && niter % plot_freq == 0) {
            splot(E, t, niter, m, n);
        }
    }

    free(E);
    free(E_prev);
    free(R);
    MPI_Finalize();
    return 0;
}

