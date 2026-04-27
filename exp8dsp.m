%% Parameters
Fs = 1000; % Sampling frequency (Hz)
N = 64; % Buffer length
t = (0:N-1)/Fs; % Time vector

%% 1. Generate signals
x1 = 100*sin(2*pi*101.56*t);
x2 = 2*sin(2*pi*156.25*t);

%% 2. FFT with rectangular window (64-point FFT)
X1 = fft(x1, N);
X2 = fft(x2, N);
f = (0:N-1)*(Fs/N);

figure;
subplot(2,1,1);
stem(f, abs(X1));
title('FFT of x1(t) - Rectangular Window, N=64');
xlabel('Frequency (Hz)'); ylabel('|X1(f)|');

subplot(2,1,2);
stem(f, abs(X2));
title('FFT of x2(t) - Rectangular Window, N=64');
xlabel('Frequency (Hz)'); ylabel('|X2(f)|');

%% 3. FFT with zero-padding (1024-point FFT)
N2 = 1024;
X1_1024 = fft(x1, N2);
X2_1024 = fft(x2, N2);
f2 = (0:N2-1)*(Fs/N2);

figure;
subplot(2,1,1);
plot(f2, abs(X1_1024));
title('FFT of x1(t) - Rectangular Window, N=1024');
xlabel('Frequency (Hz)'); ylabel('|X1(f)|');

subplot(2,1,2);
plot(f2, abs(X2_1024));
title('FFT of x2(t) - Rectangular Window, N=1024');
xlabel('Frequency (Hz)'); ylabel('|X2(f)|');

%% 4. Window functions comparison
L_values = [64, 128, 256];
windows = {@rectwin, @hann, @hamming, @blackman};

for L = L_values
figure;
for k = 1:length(windows)
w = windows{k}(L);
W = fft(w, 1024);
fW = (0:1023)*(Fs/1024);
subplot(2,2,k);
plot(fW, 20*log10(abs(W)/max(abs(W))));
title([func2str(windows{k}) ' Window, L=' num2str(L)]);
xlabel('Frequency (Hz)'); ylabel('Magnitude (dB)');
axis([0 Fs -80 5]);
end
end

%% 1. Apply Hanning window before FFT
w_hann = hann(N)';
x1_hann = x1 .* w_hann;
x2_hann = x2 .* w_hann;

X1_hann = fft(x1_hann, N);
X2_hann = fft(x2_hann, N);

figure;
subplot(2,1,1);
stem(f, abs(X1_hann));
title('FFT of x1(t) - Hanning Window, N=64');
xlabel('Frequency (Hz)'); ylabel('|X1(f)|');

subplot(2,1,2);
stem(f, abs(X2_hann));
title('FFT of x2(t) - Hanning Window, N=64');
xlabel('Frequency (Hz)'); ylabel('|X2(f)|');

%% 2. Add signals together and compare leakage
x_sum = x1 + x2;

% Rectangular window
X_sum_rect64 = fft(x_sum .* rectwin(N)', N);
X_sum_rect1024 = fft(x_sum .* rectwin(N)', 1024);

% Hamming window
X_sum_hamm64 = fft(x_sum .* hamming(N)', N);
X_sum_hamm1024 = fft(x_sum .* hamming(N)', 1024);

figure;
subplot(2,2,1); stem(f, abs(X_sum_rect64)); title('Rectangular, N=64');
subplot(2,2,2); plot(f2, abs(X_sum_rect1024)); title('Rectangular, N=1024');
subplot(2,2,3); stem(f, abs(X_sum_hamm64)); title('Hamming, N=64');
subplot(2,2,4); plot(f2, abs(X_sum_hamm1024)); title('Hamming, N=1024');

%% 3. Sampling frequency to avoid leakage
% Condition: frequencies must align exactly with FFT bins
% Bin spacing = Fs/N
% Choose Fs such that 101.56 Hz and 156.25 Hz are integer multiples of Fs/N
% Example: Fs = 10000 Hz (try multiples of N)

Fs_new = 10000;
t_new = (0:N-1)/Fs_new;
x1_new = 100*sin(2*pi*101.56*t_new);
x2_new = 2*sin(2*pi*156.25*t_new);
x_sum_new = x1_new + x2_new;

X_sum_new = fft(x_sum_new .* hamming(N)', 1024);
f_new = (0:1023)*(Fs_new/1024);

figure;
plot(f_new, abs(X_sum_new));
title('FFT with new Fs to avoid leakage');
xlabel('Frequency (Hz)'); ylabel('|X(f)|');

%% 4. Explore other windows (Kaiser, Chebyshev, etc.)
L = 64;
w_kaiser = kaiser(L, 5);
w_cheb = chebwin(L, 100);

figure;
subplot(2,1,1);
plot(20*log10(abs(fft(w_kaiser,1024))/max(abs(fft(w_kaiser,1024)))));
title('Kaiser Window Spectrum');
xlabel('Frequency bin'); ylabel('Magnitude (dB)');

subplot(2,1,2);
plot(20*log10(abs(fft(w_cheb,1024))/max(abs(fft(w_cheb,1024)))));
title('Chebyshev Window Spectrum');
xlabel('Frequency bin'); ylabel('Magnitude (dB)');
