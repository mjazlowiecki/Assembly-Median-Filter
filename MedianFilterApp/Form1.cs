using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Windows.Forms;
using System.Diagnostics;

namespace MedianFilterApp
{
    public partial class Form1 : Form
    {

        [DllImport("MedianFilterLib.dll", CallingConvention = CallingConvention.StdCall)]
        public static extern void MedianFilterCpp(IntPtr imgData, int width, int height, int stride, int numThreads, int filterSize);

        [DllImport("MedianFilterLib.dll", CallingConvention = CallingConvention.StdCall)]
        public static extern void MedianFilterAsm(IntPtr imgData, int width, int height, int stride, int numThreads, int filterSize);

        private PictureBox pbInput;
        private PictureBox pbOutput;
        private GroupBox gbInput;
        private Button btnLoadImage;

        
        private Label lblFilterSize;
        private ComboBox cbFilterSize;

        private GroupBox gbImplementation;
        private RadioButton rbCpp;
        private RadioButton rbAsm;
        private GroupBox gbThreads;
        private Label lblThreadCount;
        private TrackBar tbThreads;
        private Button btnRun;
        private GroupBox gbOutput;
        private Label lblStatus;
        private Label lblExecutionTimeCpp;
        private Label lblExecutionTimeAsm;

        public Form1()
        {
            SetupCustomComponents();
            this.Text = "Projekt JA - Filtr Medianowy";
        }


        private void BtnLoadImage_Click(object sender, EventArgs e)
        {
            using (OpenFileDialog ofd = new OpenFileDialog())
            {
                ofd.Filter = "Obrazy|*.jpg;*.png;*.bmp";
                if (ofd.ShowDialog() == DialogResult.OK)
                {
                    try
                    {
                        Bitmap temp = new Bitmap(ofd.FileName);
                        pbInput.Image = new Bitmap(temp); // Kopia, żeby nie blokować pliku
                        pbOutput.Image = null;
                        lblStatus.Text = "Wczytano: " + System.IO.Path.GetFileName(ofd.FileName);
                    }
                    catch (Exception ex) { MessageBox.Show("Błąd: " + ex.Message); }
                }
            }
        }

        private void BtnRun_Click(object sender, EventArgs e)
        {
            if (pbInput.Image == null) { MessageBox.Show("Wczytaj obraz!"); return; }

            // Pobieranie rozmiaru filtra z ComboBoxa
            int filterSize = 3; // Domyślna wartość

            // ZABEZPIECZENIE: Sprawdzamy czy ComboBox istnieje i ma wybraną wartość
            if (cbFilterSize != null && cbFilterSize.SelectedItem != null)
            {
                // Format np. "5x5" -> bierzemy pierwszy znak "5"
                string s = cbFilterSize.SelectedItem.ToString();
                int.TryParse(s.Substring(0, 1), out filterSize);
            }

            Bitmap bmp = new Bitmap(pbInput.Image);
            Rectangle rect = new Rectangle(0, 0, bmp.Width, bmp.Height);
            BitmapData bmpData = bmp.LockBits(rect, ImageLockMode.ReadWrite, PixelFormat.Format24bppRgb);

            Stopwatch watch = new Stopwatch();

            try
            {
                if (rbCpp.Checked)
                {
                    lblStatus.Text = $"C++ ({filterSize}x{filterSize})...";
                    Application.DoEvents(); // Odświeżenie interfejsu

                    watch.Start();
                    MedianFilterCpp(bmpData.Scan0, bmp.Width, bmp.Height, bmpData.Stride, tbThreads.Value, filterSize);
                    watch.Stop();

                    lblExecutionTimeCpp.Text = $"Czas C++ ({filterSize}x{filterSize}): {watch.ElapsedMilliseconds} ms";
                }
                else
                {
                    lblStatus.Text = "ASM (Fixed 3x3)...";
                    Application.DoEvents();

                    watch.Start();
                    // ignoruje
                    MedianFilterAsm(bmpData.Scan0, bmp.Width, bmp.Height, bmpData.Stride, tbThreads.Value, filterSize);
                    watch.Stop();

                    lblExecutionTimeAsm.Text = $"Czas ASM: {watch.ElapsedMilliseconds} ms";
                }
                pbOutput.Image = bmp;
            }
            catch (Exception ex)
            {
                MessageBox.Show("Błąd DLL: " + ex.Message + "\n\nUpewnij się, że przebudowałeś projekt C++ i skopiowałeś nowy plik DLL!");
            }
            finally
            {
                bmp.UnlockBits(bmpData);
            }
        }

        private void SetupCustomComponents()
        {
            this.ClientSize = new Size(1100, 750);
            this.BackColor = Color.LightGray;

            pbInput = new PictureBox { Location = new Point(20, 20), Size = new Size(500, 350), BorderStyle = BorderStyle.FixedSingle, SizeMode = PictureBoxSizeMode.Zoom, BackColor = Color.Black };
            pbOutput = new PictureBox { Location = new Point(540, 20), Size = new Size(500, 350), BorderStyle = BorderStyle.FixedSingle, SizeMode = PictureBoxSizeMode.Zoom, BackColor = Color.Black };

            // Panel: Dane wejściowe
            gbInput = new GroupBox { Text = "1. Sterowanie", Location = new Point(20, 390), Size = new Size(250, 150) };

            btnLoadImage = new Button { Text = "Wczytaj Obraz", Location = new Point(20, 30), Size = new Size(210, 40), BackColor = Color.White };
            btnLoadImage.Click += BtnLoadImage_Click;

            lblFilterSize = new Label { Text = "Rozmiar Filtru:", Location = new Point(20, 80), AutoSize = true };

            cbFilterSize = new ComboBox { Location = new Point(120, 78), Size = new Size(110, 25), DropDownStyle = ComboBoxStyle.DropDownList };
            cbFilterSize.Items.AddRange(new object[] { "3x3", "5x5", "7x7" });
            cbFilterSize.SelectedIndex = 0; // Domyślnie 3x3
            // ----------------------------------------------

            gbInput.Controls.Add(btnLoadImage);
            gbInput.Controls.Add(lblFilterSize); 
            gbInput.Controls.Add(cbFilterSize); 

            // Panel: Implementacja
            gbImplementation = new GroupBox { Text = "2. Implementacja", Location = new Point(280, 390), Size = new Size(250, 150) };
            rbCpp = new RadioButton { Text = "C++ (DLL)", Location = new Point(20, 30), Checked = true };
            rbAsm = new RadioButton { Text = "ASM x64 (DLL)", Location = new Point(20, 70) };
            gbImplementation.Controls.Add(rbCpp);
            gbImplementation.Controls.Add(rbAsm);

            // Panel: Wątki
            gbThreads = new GroupBox { Text = "3. Wątki i Start", Location = new Point(540, 390), Size = new Size(500, 150) };
            lblThreadCount = new Label { Text = "Liczba Wątków: 1", Location = new Point(20, 25), AutoSize = true };
            tbThreads = new TrackBar { Location = new Point(20, 45), Size = new Size(460, 45), Minimum = 1, Maximum = 12, Value = 1 };
            tbThreads.Scroll += (s, e) => lblThreadCount.Text = $"Liczba Wątków: {tbThreads.Value}";

            btnRun = new Button { Text = "URUCHOM OBLICZENIA", Location = new Point(20, 95), Size = new Size(460, 40), BackColor = Color.SteelBlue, ForeColor = Color.White, Font = new Font(this.Font, FontStyle.Bold) };
            btnRun.Click += BtnRun_Click;

            gbThreads.Controls.Add(lblThreadCount);
            gbThreads.Controls.Add(tbThreads);
            gbThreads.Controls.Add(btnRun);

            // Panel: Wyniki
            gbOutput = new GroupBox { Text = "4. Wyniki", Location = new Point(20, 560), Size = new Size(1020, 160) };
            lblStatus = new Label { Text = "Oczekiwanie na obraz...", Location = new Point(20, 30), Size = new Size(980, 25), BackColor = Color.White, BorderStyle = BorderStyle.FixedSingle, TextAlign = ContentAlignment.MiddleLeft };

            // Czcionki 
            lblExecutionTimeCpp = new Label { Text = "Czas C++: -- ms", Location = new Point(20, 70), AutoSize = true, Font = new Font(this.Font.FontFamily, 12.0f, FontStyle.Regular) };
            lblExecutionTimeAsm = new Label { Text = "Czas ASM: -- ms", Location = new Point(540, 70), AutoSize = true, Font = new Font(this.Font.FontFamily, 12.0f, FontStyle.Bold) };

            gbOutput.Controls.Add(lblStatus);
            gbOutput.Controls.Add(lblExecutionTimeCpp);
            gbOutput.Controls.Add(lblExecutionTimeAsm);

            this.Controls.Add(pbInput);
            this.Controls.Add(pbOutput);
            this.Controls.Add(gbInput);
            this.Controls.Add(gbImplementation);
            this.Controls.Add(gbThreads);
            this.Controls.Add(gbOutput);
        }
    }
}