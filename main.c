#include "stdio.h"

#define N_MAX 10	//滤波器最高阶数（最大支持 10）
#define X_SIZE 12	//输入序列长度 12

// Necessary function to enable printf() using semihosting
extern void initialise_monitor_handles(void);

extern int iir(int N, int* b, int* a, int x_n); // asm implementation
int iir_c(int N, int* b, int* a, int x_n); // reference C implementation

//iir(N,b,a,x_n) 中 R0=N, R1=b*, R2=a*, R3=x_n。返回值放 R0。

int main(void)
{
	// Necessary function to enable printf() using semihosting
	initialise_monitor_handles();

	//variables
	int i;
	int N = 4;

	//  NOTE: DO NOT modify the code below this line
	// think of the values below as numbers of the form y.yy (floating point with 2 digits precision)
	// which are scaled up to allow them to be used integers
	// within the iir function, we divide y by 100 (decimal) to scale it down
	// 把 y.yy 这种两位小数，放大 100 变成整数参与计算；返回前再 /100 缩回

	int b[N_MAX+1] = {100, 250, 360, 450, 580}; //N+1 dimensional feedforward
	int a[N_MAX+1] = {100, 120, 180, 230, 250}; //N+1 dimensional feedback
	int x[X_SIZE] = {100, 230, 280, 410, 540, 600, 480, 390, 250, 160, 100, 340};
	//	b[]、a[] 都开到 N_MAX+1，即便 N=4，后面的槽位会自动补 0（C 规则）。
	//	这使得后面循环里访问 b[j+1] 在 j=N（即 b[5]）也安全——它是 0。

	// Call assembly language function iir for each element of x
	for (i=0; i<X_SIZE; i++)	//对每个输入样本 x[i]：
	{
		printf( "asm: i = %d, y_n = %d, \n", i, iir(N, b, a, x[i]) ) ;	//调汇编 iir(...) 算一个 y[n]，打印
		printf( "C  : i = %d, y_n = %d, \n", i, iir_c(N, b, a, x[i]) ) ;	//调 C 参考 iir_c(...) 算一个 y[n]，打印
//		两行输出应数值一致（这就是验证自己 iir.s 是否正确的方式）
	}
	while (1); //halt 在嵌入式里保持程序“驻留”，便于看终端输出或继续调试
}

//iir_c() 内部机制，照它实现ASM
int iir_c(int N, int* b, int* a, int x_n)
{ 	// The implementation below is inefficient and meant only for verifying your results.

	//保存过去的 x[n-1..n-N] 和 y[n-1..n-N]。初值为 0
	static int x_store[N_MAX] = {0}; // to store the previous N values of x_n.
	static int y_store[N_MAX] = {0}; // to store the previous values of y_n.

	int j;
	int y_n;
	//计算基项
	y_n = x_n*b[0]/a[0];

	for (j=0; j<N; j++)
	{
		//公式
		y_n+=(b[j+1]*x_store[j]-a[j+1]*y_store[j])/a[0];
		//注意：这里是每一项都先除以 a0 再累加（整数截断会影响结果）
		//汇编要严格跟它一致，否则会有 1 的偏差。
	}

	for (j=N-1; j>0; j--)
	{
		//把旧的 x[n-1] 移到 x[n-2]
		x_store[j] = x_store[j-1];
		y_store[j] = y_store[j-1];
	}
	//把当前 x_n、y_n 放到槽 0，供下一次调用使用
	x_store[0] = x_n;
	y_store[0] = y_n;
	//把累计的“放大 100 倍”的结果除以 100，返回整数 y
	y_n /= 100; // scaling down

	return y_n;
}
