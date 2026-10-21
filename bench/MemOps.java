// Microbenchmark for HotSpot's memory-operation stubs (arraycopy, fill, equals) at the sizes Minecraft uses: run twice with
// and without a flag (e.g. -XX:+UseSIMDForMemoryOps) on an idle Mac; prints ns per operation per size, median of 7 rounds.
import java.util.Arrays;

public class MemOps {
	static volatile long sink;

	public static void main(String[] a) {
		int[] sizes = {16, 64, 256, 1024, 4096, 16384, 65536};
		for (int round = 0; round < 2; round++) run(sizes, round == 1);
	}

	static void run(int[] sizes, boolean print) {
		for (int n : sizes) {
			byte[] b1 = new byte[n], b2 = new byte[n];
			long[] l1 = new long[n / 8 + 1], l2 = new long[n / 8 + 1];
			int reps = Math.max(2000, 20_000_000 / n);
			double[] copy = new double[7], fill = new double[7], eq = new double[7], lcopy = new double[7];
			for (int r = 0; r < 7; r++) {
				long t = System.nanoTime();
				for (int i = 0; i < reps; i++) System.arraycopy(b1, 0, b2, 0, n);
				copy[r] = (System.nanoTime() - t) / (double) reps;
				t = System.nanoTime();
				for (int i = 0; i < reps; i++) Arrays.fill(b2, (byte) i);
				fill[r] = (System.nanoTime() - t) / (double) reps;
				t = System.nanoTime();
				long s = 0;
				for (int i = 0; i < reps; i++) if (Arrays.equals(b1, b2)) s++;
				eq[r] = (System.nanoTime() - t) / (double) reps;
				t = System.nanoTime();
				for (int i = 0; i < reps; i++) System.arraycopy(l1, 0, l2, 0, l1.length);
				lcopy[r] = (System.nanoTime() - t) / (double) reps;
				sink += s + b2[n - 1] + l2[0];
			}
			if (print) System.out.printf("%6d B  copy %8.2f  fill %8.2f  equals %8.2f  long-copy %8.2f ns%n", n, med(copy), med(fill), med(eq), med(lcopy));
		}
	}

	static double med(double[] v) {
		double[] c = v.clone();
		Arrays.sort(c);
		return c[c.length / 2];
	}
}
