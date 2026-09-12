using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Documents;
using System.Windows.Input;
using System.Windows.Media;
using Microsoft.Win32;

namespace CryOfFearHDRConfig
{
    public class Program : Application
    {
        public const string Version = "1.3.0";

        [STAThread]
        public static void Main()
        {
            var app = new Program();
            app.Run(new MainWindow());
        }
    }

    internal sealed class ResolutionChoice
    {
        public int Width;
        public int Height;
        public string Label;
        public bool IsCustom;
        public bool IsDesktop;
        public override string ToString() { return Label; }
    }

    public class MainWindow : Window
    {
        private const int ENUM_CURRENT_SETTINGS = -1;

        private TextBox txtGamePath;
        private ComboBox cmbResolution;
        private ComboBox cmbDisplayMode;
        private TextBox txtWidth;
        private TextBox txtHeight;
        private TextBox txtLaunch;
        private Slider sliderFov;
        private TextBlock lblFovValue;
        private CheckBox chkRawMouse;
        private CheckBox chkLowLatencyVsync;
        private CheckBox chkEngineRates;
        private CheckBox chkRtxHdr;
        private CheckBox chkSoftenedShader;
        private RichTextBox txtLog;
        private Paragraph logParagraph;
        private Border chipPath;
        private Border chipHdr;
        private Border chipAuto;
        private TextBlock chipPathText;
        private TextBlock chipHdrText;
        private TextBlock chipAutoText;
        private Border checklistCard;
        private TextBlock checklistBody;
        private Button btnInstall;
        private Button btnTest;
        private Button btnRevert;
        private Button btnBrowse;
        private Button btnRefresh;
        private Button btnHdrSettings;
        private Button btnIndicator;
        private Button btnCopyLaunch;
        private TextBlock lblBusy;

        private bool _busy;
        private bool _updatingResolutionFields;
        private string _steamStatus;
        private string _profileStatus;

        public MainWindow()
        {
            Title = "Cry of Fear: RTX HDR Configurator  v" + Program.Version;
            Width = 860;
            Height = 860;
            MinWidth = 760;
            MinHeight = 640;
            WindowStartupLocation = WindowStartupLocation.CenterScreen;
            Background = new SolidColorBrush(Color.FromRgb(18, 20, 26));
            Foreground = new SolidColorBrush(Color.FromRgb(236, 239, 244));
            FontFamily = new FontFamily("Segoe UI, Arial");

            BuildUI();
            InitializeDefaultValues();
        }

        private static readonly Color ColBg = Color.FromRgb(18, 20, 26);
        private static readonly Color ColCard = Color.FromRgb(24, 27, 35);
        private static readonly Color ColHeader = Color.FromRgb(26, 29, 38);
        private static readonly Color ColInput = Color.FromRgb(32, 36, 47);
        private static readonly Color ColMuted = Color.FromRgb(140, 148, 165);
        private static readonly Color ColOk = Color.FromRgb(46, 125, 50);
        private static readonly Color ColWarn = Color.FromRgb(140, 100, 20);
        private static readonly Color ColFail = Color.FromRgb(140, 40, 40);
        private static readonly Color ColIdle = Color.FromRgb(50, 55, 68);

        private void BuildUI()
        {
            var grid = new Grid { Margin = new Thickness(20) };
            grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            grid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
            grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });

            grid.Children.Add(BuildHeader());
            Grid.SetRow(grid.Children[grid.Children.Count - 1], 0);

            var scrollViewer = new ScrollViewer { VerticalScrollBarVisibility = ScrollBarVisibility.Auto };
            var bodyStack = new StackPanel { Margin = new Thickness(0, 0, 10, 0) };

            StackPanel pathPanel;
            bodyStack.Children.Add(CreateCard("1. Game folder", out pathPanel));
            var pathRow = new Grid();
            pathRow.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            pathRow.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
            txtGamePath = MakeTextBox("");
            txtGamePath.TextChanged += (s, e) => RefreshPathChip();
            btnBrowse = CreateButton("Browse...", 90, 32);
            btnBrowse.Margin = new Thickness(10, 0, 0, 0);
            btnBrowse.Click += (s, e) => BrowseGameFolder();
            Grid.SetColumn(txtGamePath, 0);
            Grid.SetColumn(btnBrowse, 1);
            pathRow.Children.Add(txtGamePath);
            pathRow.Children.Add(btnBrowse);
            pathPanel.Children.Add(pathRow);

            StackPanel displayPanel;
            bodyStack.Children.Add(CreateCard("2. Display", out displayPanel));
            var dispGrid = new Grid();
            dispGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            dispGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });

            var resBox = new StackPanel { Margin = new Thickness(0, 0, 10, 0) };
            resBox.Children.Add(Muted("Resolution"));
            cmbResolution = MakeCombo();
            cmbResolution.SelectionChanged += (s, e) => OnResolutionChanged();
            resBox.Children.Add(cmbResolution);

            var customRow = new Grid { Margin = new Thickness(0, 8, 0, 0) };
            customRow.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            customRow.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
            customRow.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            txtWidth = MakeTextBox("2560");
            txtHeight = MakeTextBox("1440");
            txtWidth.TextChanged += (s, e) => { if (!_updatingResolutionFields) UpdateLaunchOptions(); };
            txtHeight.TextChanged += (s, e) => { if (!_updatingResolutionFields) UpdateLaunchOptions(); };
            var xLabel = new TextBlock
            {
                Text = " × ",
                Foreground = new SolidColorBrush(ColMuted),
                VerticalAlignment = VerticalAlignment.Center
            };
            Grid.SetColumn(txtWidth, 0);
            Grid.SetColumn(xLabel, 1);
            Grid.SetColumn(txtHeight, 2);
            customRow.Children.Add(txtWidth);
            customRow.Children.Add(xLabel);
            customRow.Children.Add(txtHeight);
            resBox.Children.Add(customRow);

            var modeBox = new StackPanel { Margin = new Thickness(10, 0, 0, 0) };
            modeBox.Children.Add(Muted("Window mode"));
            cmbDisplayMode = MakeCombo();
            cmbDisplayMode.Items.Add("Fullscreen (recommended)");
            cmbDisplayMode.Items.Add("Windowed (with borders)");
            cmbDisplayMode.SelectedIndex = 0;
            cmbDisplayMode.SelectionChanged += (s, e) => UpdateLaunchOptions();
            modeBox.Children.Add(cmbDisplayMode);

            Grid.SetColumn(resBox, 0);
            Grid.SetColumn(modeBox, 1);
            dispGrid.Children.Add(resBox);
            dispGrid.Children.Add(modeBox);
            displayPanel.Children.Add(dispGrid);

            displayPanel.Children.Add(Muted("Steam launch options"));
            var launchRow = new Grid { Margin = new Thickness(0, 4, 0, 0) };
            launchRow.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            launchRow.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
            txtLaunch = MakeTextBox("");
            txtLaunch.IsReadOnly = true;
            txtLaunch.FontFamily = new FontFamily("Consolas, Courier New");
            txtLaunch.FontSize = 12;
            btnCopyLaunch = CreateButton("Copy", 80, 32);
            btnCopyLaunch.Margin = new Thickness(10, 0, 0, 0);
            btnCopyLaunch.Click += (s, e) => CopyLaunchOptions();
            Grid.SetColumn(txtLaunch, 0);
            Grid.SetColumn(btnCopyLaunch, 1);
            launchRow.Children.Add(txtLaunch);
            launchRow.Children.Add(btnCopyLaunch);
            displayPanel.Children.Add(launchRow);

            StackPanel fovPanel;
            bodyStack.Children.Add(CreateCard("3. Field of view", out fovPanel));
            var fovHeader = new Grid();
            fovHeader.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            fovHeader.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
            var fovDesc = new TextBlock
            {
                Text = "Widens the stock 4:3 camera for 16:9 monitors.",
                Foreground = new SolidColorBrush(ColMuted),
                VerticalAlignment = VerticalAlignment.Center
            };
            lblFovValue = new TextBlock
            {
                Text = "1.15  (~104°  recommended)",
                FontWeight = FontWeights.Bold,
                Foreground = new SolidColorBrush(Color.FromRgb(0, 229, 255)),
                VerticalAlignment = VerticalAlignment.Center
            };
            Grid.SetColumn(fovDesc, 0);
            Grid.SetColumn(lblFovValue, 1);
            fovHeader.Children.Add(fovDesc);
            fovHeader.Children.Add(lblFovValue);
            fovPanel.Children.Add(fovHeader);
            sliderFov = new Slider
            {
                Minimum = 1.00,
                Maximum = 1.30,
                Value = 1.15,
                TickFrequency = 0.05,
                IsSnapToTickEnabled = false,
                Margin = new Thickness(0, 10, 0, 0)
            };
            sliderFov.ValueChanged += (s, e) =>
            {
                double val = Math.Round(sliderFov.Value, 2);
                int deg = (int)Math.Round(val * 90.0);
                string note = val == 1.00 ? "vanilla 4:3" : val == 1.15 ? "recommended" : val > 1.20 ? "very wide" : "subtle";
                lblFovValue.Text = string.Format("{0:F2}  (~{1}°  {2})", val, deg, note);
            };
            sliderFov.ToolTip = "cl_fovmultiplier";
            fovPanel.Children.Add(sliderFov);

            StackPanel latPanel;
            bodyStack.Children.Add(CreateCard("4. Input latency", out latPanel));
            chkRawMouse = MakeCheck("Raw mouse (no smoothing)", "m_filter 0 — disables GoldSrc's 2-frame mouse filter", true);
            chkLowLatencyVsync = MakeCheck("Disable VSync buffer", "gl_vsync 0 — use G-Sync / VRR for tear control", true);
            chkEngineRates = MakeCheck("High engine tickrate", "cl_cmdrate 101, cl_updaterate 101, rate 100000", true);
            latPanel.Children.Add(chkRawMouse);
            latPanel.Children.Add(chkLowLatencyVsync);
            latPanel.Children.Add(chkEngineRates);

            StackPanel gfxPanel;
            bodyStack.Children.Add(CreateCard("5. Visuals", out gfxPanel));
            chkRtxHdr = MakeCheck("RTX HDR + 16× anisotropic filtering", "Route 3B driver profile: layered DXGI, VeryHigh debanding, MSAA off", true);
            chkSoftenedShader = MakeCheck("Soften nightmare shader", "Replaces black_fp.cg so the B/W effect does not flash to panel peak", false);
            gfxPanel.Children.Add(chkRtxHdr);
            gfxPanel.Children.Add(chkSoftenedShader);
            gfxPanel.Children.Add(new TextBlock
            {
                Text = "MSAA stays off (map-load crashes). Install checks Windows HDR and turns Auto HDR off for cof.exe only.",
                Foreground = new SolidColorBrush(ColMuted),
                FontSize = 12,
                Margin = new Thickness(0, 8, 0, 0),
                TextWrapping = TextWrapping.Wrap
            });

            scrollViewer.Content = bodyStack;
            Grid.SetRow(scrollViewer, 1);
            grid.Children.Add(scrollViewer);

            checklistCard = new Border
            {
                Background = new SolidColorBrush(Color.FromRgb(22, 40, 32)),
                CornerRadius = new CornerRadius(8),
                Padding = new Thickness(14),
                Margin = new Thickness(0, 12, 0, 0),
                BorderBrush = new SolidColorBrush(Color.FromRgb(46, 125, 50)),
                BorderThickness = new Thickness(1),
                Visibility = Visibility.Collapsed
            };
            var checkStack = new StackPanel();
            checkStack.Children.Add(new TextBlock
            {
                Text = "Installed — finish in Steam",
                FontWeight = FontWeights.SemiBold,
                FontSize = 14,
                Margin = new Thickness(0, 0, 0, 6)
            });
            checklistBody = new TextBlock
            {
                TextWrapping = TextWrapping.Wrap,
                FontSize = 13,
                Foreground = new SolidColorBrush(Color.FromRgb(210, 230, 215))
            };
            checkStack.Children.Add(checklistBody);
            checklistCard.Child = checkStack;
            Grid.SetRow(checklistCard, 2);
            grid.Children.Add(checklistCard);

            var footer = new StackPanel { Margin = new Thickness(0, 12, 0, 0) };
            var btnRow = new Grid();
            btnRow.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
            btnRow.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
            btnRow.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
            btnRow.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
            btnRow.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            btnInstall = CreatePrimaryButton("Install", 140, 40);
            btnInstall.Click += (s, e) => ApplyAndInstall();
            btnTest = CreateButton("Diagnose", 120, 40);
            btnTest.Click += (s, e) => RunDiagnostics();
            btnRevert = CreateDangerButton("Revert", 120, 40);
            btnRevert.Click += (s, e) => RevertStock();
            btnIndicator = CreateButton("HDR indicator", 130, 40);
            btnIndicator.ToolTip = "Imports the driver profile with an on-screen marker so you can confirm RTX HDR is running. Click Install afterwards to hide the marker.";
            btnIndicator.Click += (s, e) => ImportHdrIndicator();
            lblBusy = new TextBlock
            {
                Text = "",
                Foreground = new SolidColorBrush(ColMuted),
                VerticalAlignment = VerticalAlignment.Center,
                Margin = new Thickness(12, 0, 0, 0)
            };
            Grid.SetColumn(btnInstall, 0);
            Grid.SetColumn(btnTest, 1);
            Grid.SetColumn(btnRevert, 2);
            Grid.SetColumn(btnIndicator, 3);
            Grid.SetColumn(lblBusy, 4);
            btnTest.Margin = new Thickness(0, 0, 10, 0);
            btnRevert.Margin = new Thickness(0, 0, 10, 0);
            btnIndicator.Margin = new Thickness(0, 0, 10, 0);
            btnRow.Children.Add(btnInstall);
            btnRow.Children.Add(btnTest);
            btnRow.Children.Add(btnRevert);
            btnRow.Children.Add(btnIndicator);
            btnRow.Children.Add(lblBusy);
            footer.Children.Add(btnRow);

            logParagraph = new Paragraph { Margin = new Thickness(0) };
            txtLog = new RichTextBox
            {
                Background = new SolidColorBrush(Color.FromRgb(14, 16, 22)),
                Foreground = new SolidColorBrush(Color.FromRgb(180, 240, 180)),
                BorderBrush = new SolidColorBrush(Color.FromRgb(40, 45, 55)),
                Height = 180,
                IsReadOnly = true,
                VerticalScrollBarVisibility = ScrollBarVisibility.Auto,
                FontFamily = new FontFamily("Consolas, Courier New"),
                FontSize = 12,
                Padding = new Thickness(8),
                Margin = new Thickness(0, 10, 0, 0),
                Document = new FlowDocument(logParagraph)
            };
            footer.Children.Add(txtLog);
            Grid.SetRow(footer, 3);
            grid.Children.Add(footer);

            Content = grid;
        }

        private UIElement BuildHeader()
        {
            var headerBorder = new Border
            {
                Background = new SolidColorBrush(ColHeader),
                CornerRadius = new CornerRadius(10),
                Padding = new Thickness(16),
                Margin = new Thickness(0, 0, 0, 12),
                BorderBrush = new SolidColorBrush(Color.FromRgb(45, 49, 60)),
                BorderThickness = new Thickness(1)
            };
            var headerStack = new StackPanel();
            var titleRow = new StackPanel { Orientation = Orientation.Horizontal };
            titleRow.Children.Add(new TextBlock
            {
                Text = "CRY OF FEAR",
                FontSize = 22,
                FontWeight = FontWeights.Bold,
                Foreground = new SolidColorBrush(Color.FromRgb(240, 244, 250))
            });
            var badge = new Border
            {
                Background = new SolidColorBrush(Color.FromRgb(118, 185, 0)),
                CornerRadius = new CornerRadius(4),
                Padding = new Thickness(8, 2, 8, 2),
                Margin = new Thickness(12, 0, 0, 0),
                VerticalAlignment = VerticalAlignment.Center
            };
            badge.Child = new TextBlock
            {
                Text = "RTX HDR  v" + Program.Version,
                FontWeight = FontWeights.Bold,
                FontSize = 12,
                Foreground = Brushes.Black
            };
            titleRow.Children.Add(badge);
            headerStack.Children.Add(titleRow);
            headerStack.Children.Add(new TextBlock
            {
                Text = "Portable installer  ·  Collin Lerche (zfzfg) — STERRA",
                FontSize = 12,
                Foreground = new SolidColorBrush(ColMuted),
                Margin = new Thickness(0, 4, 0, 10)
            });

            var chipRow = new StackPanel { Orientation = Orientation.Horizontal };
            chipPath = MakeChip("Game: …", out chipPathText);
            chipHdr = MakeChip("Windows HDR: …", out chipHdrText);
            chipAuto = MakeChip("Auto HDR: …", out chipAutoText);
            chipRow.Children.Add(chipPath);
            chipRow.Children.Add(chipHdr);
            chipRow.Children.Add(chipAuto);
            btnRefresh = CreateButton("Refresh", 80, 28);
            btnRefresh.Click += (s, e) => RefreshStatus();
            chipRow.Children.Add(btnRefresh);
            btnHdrSettings = CreateButton("HDR settings", 110, 28);
            btnHdrSettings.Click += (s, e) => OpenHdrSettings();
            chipRow.Children.Add(btnHdrSettings);
            headerStack.Children.Add(chipRow);
            headerBorder.Child = headerStack;
            return headerBorder;
        }

        private Border MakeChip(string text, out TextBlock tb)
        {
            tb = new TextBlock
            {
                Text = text,
                FontSize = 11,
                FontWeight = FontWeights.SemiBold,
                Foreground = Brushes.White
            };
            return new Border
            {
                CornerRadius = new CornerRadius(11),
                Padding = new Thickness(10, 4, 10, 4),
                Margin = new Thickness(0, 0, 8, 0),
                Background = new SolidColorBrush(ColIdle),
                VerticalAlignment = VerticalAlignment.Center,
                Child = tb
            };
        }

        private static void SetChip(Border border, TextBlock tb, string text, Color bg)
        {
            tb.Text = text;
            border.Background = new SolidColorBrush(bg);
        }

        private TextBlock Muted(string text)
        {
            return new TextBlock
            {
                Text = text,
                Foreground = new SolidColorBrush(ColMuted),
                Margin = new Thickness(0, 8, 0, 5)
            };
        }

        private TextBox MakeTextBox(string text)
        {
            return new TextBox
            {
                Text = text,
                Background = new SolidColorBrush(ColInput),
                Foreground = Brushes.White,
                BorderBrush = new SolidColorBrush(Color.FromRgb(60, 66, 82)),
                Padding = new Thickness(8, 6, 8, 6),
                FontSize = 13,
                CaretBrush = Brushes.White,
                VerticalAlignment = VerticalAlignment.Center
            };
        }

        private ComboBox MakeCombo()
        {
            return new ComboBox
            {
                Height = 30,
                Background = Brushes.White,
                Foreground = Brushes.Black
            };
        }

        private CheckBox MakeCheck(string label, string tooltip, bool on)
        {
            return new CheckBox
            {
                Content = label,
                ToolTip = tooltip,
                IsChecked = on,
                Foreground = Brushes.White,
                Margin = new Thickness(0, 4, 0, 4)
            };
        }

        private Border CreateCard(string title, out StackPanel contentPanel)
        {
            var border = new Border
            {
                Background = new SolidColorBrush(ColCard),
                CornerRadius = new CornerRadius(8),
                Padding = new Thickness(14),
                Margin = new Thickness(0, 0, 0, 12),
                BorderBrush = new SolidColorBrush(Color.FromRgb(38, 43, 54)),
                BorderThickness = new Thickness(1)
            };
            var stack = new StackPanel();
            stack.Children.Add(new TextBlock
            {
                Text = title,
                FontSize = 14,
                FontWeight = FontWeights.SemiBold,
                Foreground = new SolidColorBrush(Color.FromRgb(220, 225, 235)),
                Margin = new Thickness(0, 0, 0, 10)
            });
            contentPanel = new StackPanel();
            stack.Children.Add(contentPanel);
            border.Child = stack;
            return border;
        }

        private Button CreatePrimaryButton(string text, double width, double height)
        {
            return new Button
            {
                Content = text,
                Width = width,
                Height = height,
                Background = new SolidColorBrush(Color.FromRgb(0, 180, 80)),
                Foreground = Brushes.White,
                FontWeight = FontWeights.Bold,
                FontSize = 13,
                Margin = new Thickness(0, 0, 10, 0),
                Cursor = Cursors.Hand
            };
        }

        private Button CreateButton(string text, double width, double height)
        {
            return new Button
            {
                Content = text,
                Width = width,
                Height = height,
                Background = new SolidColorBrush(Color.FromRgb(36, 41, 52)),
                Foreground = Brushes.White,
                FontSize = 12,
                Margin = new Thickness(0, 0, 10, 0),
                BorderBrush = new SolidColorBrush(Color.FromRgb(55, 62, 78)),
                Cursor = Cursors.Hand
            };
        }

        private Button CreateDangerButton(string text, double width, double height)
        {
            return new Button
            {
                Content = text,
                Width = width,
                Height = height,
                Background = new SolidColorBrush(Color.FromRgb(70, 30, 35)),
                Foreground = new SolidColorBrush(Color.FromRgb(255, 120, 120)),
                FontSize = 12,
                BorderBrush = new SolidColorBrush(Color.FromRgb(120, 50, 55)),
                Cursor = Cursors.Hand
            };
        }

        private void Log(string msg)
        {
            if (msg == null) return;
            msg = msg.TrimEnd('\r');
            if (msg.Length == 0) return;

            if (msg.IndexOf("[STEAM] written", StringComparison.OrdinalIgnoreCase) >= 0)
                _steamStatus = "written";
            else if (msg.IndexOf("[STEAM] not-written", StringComparison.OrdinalIgnoreCase) >= 0)
                _steamStatus = "not-written";
            if (msg.IndexOf("[PROFILE] imported", StringComparison.OrdinalIgnoreCase) >= 0)
                _profileStatus = "imported";
            else if (msg.IndexOf("[PROFILE] failed", StringComparison.OrdinalIgnoreCase) >= 0)
                _profileStatus = "failed";
            else if (msg.IndexOf("[PROFILE] skipped", StringComparison.OrdinalIgnoreCase) >= 0)
                _profileStatus = "skipped";

            Brush brush = new SolidColorBrush(Color.FromRgb(180, 240, 180));
            string upper = msg.ToUpperInvariant();
            if (upper.Contains("[FAIL]") || upper.Contains("ERROR:"))
                brush = new SolidColorBrush(Color.FromRgb(255, 120, 120));
            else if (upper.Contains("[WARN]"))
                brush = new SolidColorBrush(Color.FromRgb(240, 210, 120));
            else if (upper.Contains("[PASS]") || upper.Contains("[OK]"))
                brush = new SolidColorBrush(Color.FromRgb(140, 220, 140));
            else if (upper.Contains("[?]"))
                brush = new SolidColorBrush(ColMuted);

            var run = new Run(string.Format("[{0:HH:mm:ss}] {1}\n", DateTime.Now, msg)) { Foreground = brush };
            logParagraph.Inlines.Add(run);
            txtLog.ScrollToEnd();
        }

        private void InitializeDefaultValues()
        {
            FillResolutions();
            if (!LoadSettings())
            {
                string detected = FindCryOfFear();
                if (!string.IsNullOrEmpty(detected))
                {
                    txtGamePath.Text = detected;
                    Log("Auto-detected Cry of Fear at: " + detected);
                }
                else
                {
                    Log("Cry of Fear path not found automatically. Please select it manually.");
                }
            }
            RefreshStatus();
            UpdateLaunchOptions();
        }

        private void FillResolutions()
        {
            cmbResolution.Items.Clear();
            int dw, dh;
            GetDesktopPixels(out dw, out dh);

            var desktop = new ResolutionChoice
            {
                Width = dw,
                Height = dh,
                IsDesktop = true,
                Label = string.Format("Desktop native ({0}×{1})", dw, dh)
            };
            cmbResolution.Items.Add(desktop);

            var seen = new HashSet<string>();
            seen.Add(dw + "x" + dh);
            foreach (var mode in EnumerateDisplayModes())
            {
                string key = mode.Width + "x" + mode.Height;
                if (!seen.Add(key)) continue;
                mode.Label = string.Format("{0}×{1}", mode.Width, mode.Height);
                cmbResolution.Items.Add(mode);
            }

            cmbResolution.Items.Add(new ResolutionChoice
            {
                Width = dw,
                Height = dh,
                IsCustom = true,
                Label = "Custom"
            });
            cmbResolution.SelectedIndex = 0;
            ApplyResolutionToFields();
        }

        private static List<ResolutionChoice> EnumerateDisplayModes()
        {
            var list = new List<ResolutionChoice>();
            var dm = new DEVMODE();
            dm.dmSize = (short)Marshal.SizeOf(typeof(DEVMODE));
            int i = 0;
            while (EnumDisplaySettings(null, i, ref dm))
            {
                if (dm.dmPelsWidth >= 640 && dm.dmPelsHeight >= 480)
                {
                    list.Add(new ResolutionChoice
                    {
                        Width = dm.dmPelsWidth,
                        Height = dm.dmPelsHeight
                    });
                }
                i++;
            }
            list.Sort(delegate(ResolutionChoice a, ResolutionChoice b)
            {
                int cmp = (b.Width * b.Height).CompareTo(a.Width * a.Height);
                if (cmp != 0) return cmp;
                return b.Width.CompareTo(a.Width);
            });
            return list;
        }

        private static void GetDesktopPixels(out int width, out int height)
        {
            var dm = new DEVMODE();
            dm.dmSize = (short)Marshal.SizeOf(typeof(DEVMODE));
            if (EnumDisplaySettings(null, ENUM_CURRENT_SETTINGS, ref dm) && dm.dmPelsWidth > 0)
            {
                width = dm.dmPelsWidth;
                height = dm.dmPelsHeight;
                return;
            }
            width = GetSystemMetrics(0);
            height = GetSystemMetrics(1);
            if (width < 640) width = 1920;
            if (height < 480) height = 1080;
        }

        private ResolutionChoice CurrentChoice()
        {
            return cmbResolution.SelectedItem as ResolutionChoice;
        }

        private void OnResolutionChanged()
        {
            ApplyResolutionToFields();
            UpdateLaunchOptions();
        }

        private void ApplyResolutionToFields()
        {
            var choice = CurrentChoice();
            _updatingResolutionFields = true;
            try
            {
                if (choice == null)
                {
                    txtWidth.IsReadOnly = true;
                    txtHeight.IsReadOnly = true;
                    return;
                }
                if (choice.IsCustom)
                {
                    txtWidth.IsReadOnly = false;
                    txtHeight.IsReadOnly = false;
                }
                else
                {
                    txtWidth.Text = choice.Width.ToString(CultureInfo.InvariantCulture);
                    txtHeight.Text = choice.Height.ToString(CultureInfo.InvariantCulture);
                    txtWidth.IsReadOnly = true;
                    txtHeight.IsReadOnly = true;
                }
            }
            finally
            {
                _updatingResolutionFields = false;
            }
        }

        private bool TryGetResolution(out int width, out int height)
        {
            width = 0;
            height = 0;
            var choice = CurrentChoice();
            if (choice != null && !choice.IsCustom)
            {
                width = choice.Width;
                height = choice.Height;
                return width >= 640 && height >= 480;
            }
            if (!int.TryParse(txtWidth.Text.Trim(), NumberStyles.Integer, CultureInfo.InvariantCulture, out width) ||
                !int.TryParse(txtHeight.Text.Trim(), NumberStyles.Integer, CultureInfo.InvariantCulture, out height) ||
                width < 640 || height < 480)
            {
                MessageBox.Show("Enter a resolution of at least 640×480.", "Invalid resolution", MessageBoxButton.OK, MessageBoxImage.Warning);
                return false;
            }
            return true;
        }

        private string BuildLaunchOptions()
        {
            int width, height;
            if (!TryGetResolution(out width, out height)) return null;
            bool windowed = cmbDisplayMode.SelectedIndex == 1;
            string modeFlag = windowed
                ? string.Format("-window -w {0} -h {1}", width, height)
                : string.Format("-fullscreen -w {0} -h {1}", width, height);
            return modeFlag + " -noforcemparms -noforcemaccel -noforcemspd";
        }

        private void UpdateLaunchOptions()
        {
            if (txtLaunch == null) return;
            int width, height;
            var choice = CurrentChoice();
            if (choice != null && !choice.IsCustom)
            {
                width = choice.Width;
                height = choice.Height;
            }
            else if (!int.TryParse(txtWidth.Text.Trim(), NumberStyles.Integer, CultureInfo.InvariantCulture, out width) ||
                     !int.TryParse(txtHeight.Text.Trim(), NumberStyles.Integer, CultureInfo.InvariantCulture, out height))
            {
                txtLaunch.Text = "";
                return;
            }
            bool windowed = cmbDisplayMode != null && cmbDisplayMode.SelectedIndex == 1;
            string modeFlag = windowed
                ? string.Format("-window -w {0} -h {1}", width, height)
                : string.Format("-fullscreen -w {0} -h {1}", width, height);
            txtLaunch.Text = modeFlag + " -noforcemparms -noforcemaccel -noforcemspd";
        }

        private void RefreshPathChip()
        {
            string gameDir = txtGamePath.Text.Trim();
            bool ok = !string.IsNullOrEmpty(gameDir) && File.Exists(Path.Combine(gameDir, "cof.exe"));
            SetChip(chipPath, chipPathText, ok ? "Game: found" : "Game: missing cof.exe", ok ? ColOk : ColFail);
        }

        private void RefreshStatus()
        {
            RefreshPathChip();

            bool queried;
            bool anyOn;
            HdrProbe.TryProbe(out queried, out anyOn);
            if (!queried)
                SetChip(chipHdr, chipHdrText, "Windows HDR: unknown", ColIdle);
            else if (anyOn)
                SetChip(chipHdr, chipHdrText, "Windows HDR: on", ColOk);
            else
                SetChip(chipHdr, chipHdrText, "Windows HDR: off", ColFail);

            string exe = "";
            if (!string.IsNullOrWhiteSpace(txtGamePath.Text))
                exe = Path.Combine(txtGamePath.Text.Trim(), "cof.exe");
            string pref = null;
            try
            {
                using (var key = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\DirectX\UserGpuPreferences"))
                {
                    if (key != null && !string.IsNullOrEmpty(exe))
                        pref = key.GetValue(exe) as string;
                }
            }
            catch { }

            if (!string.IsNullOrEmpty(pref) && pref.IndexOf("AutoHDREnable=0", StringComparison.OrdinalIgnoreCase) >= 0)
                SetChip(chipAuto, chipAutoText, "Auto HDR (CoF): off", ColOk);
            else
                SetChip(chipAuto, chipAutoText, "Auto HDR (CoF): not overridden", ColWarn);
        }

        private string FindCryOfFear()
        {
            try
            {
                using (var key = Registry.CurrentUser.OpenSubKey(@"Software\Valve\Steam"))
                {
                    if (key == null) return null;
                    string steamPath = key.GetValue("SteamPath") as string;
                    if (string.IsNullOrEmpty(steamPath)) return null;

                    string defaultCandidate = Path.Combine(steamPath, @"steamapps\common\Cry of Fear");
                    if (File.Exists(Path.Combine(defaultCandidate, "cof.exe"))) return defaultCandidate;

                    string vdf = Path.Combine(steamPath, @"steamapps\libraryfolders.vdf");
                    if (File.Exists(vdf))
                    {
                        string content = File.ReadAllText(vdf);
                        var matches = Regex.Matches(content, @"""path""\s+""([^""]+)""");
                        foreach (Match m in matches)
                        {
                            string lib = m.Groups[1].Value.Replace(@"\\", @"\");
                            string candidate = Path.Combine(lib, @"steamapps\common\Cry of Fear");
                            if (File.Exists(Path.Combine(candidate, "cof.exe"))) return candidate;
                        }
                    }
                }
            }
            catch { }
            return null;
        }

        private void BrowseGameFolder()
        {
            var dlg = new OpenFileDialog
            {
                Title = "Select Cry of Fear Executable (cof.exe)",
                Filter = "Cry of Fear Executable (cof.exe)|cof.exe|All Executables (*.exe)|*.exe",
                FileName = "cof.exe"
            };
            if (dlg.ShowDialog() == true)
            {
                txtGamePath.Text = Path.GetDirectoryName(dlg.FileName);
                Log("Selected game folder: " + txtGamePath.Text);
                RefreshStatus();
            }
        }

        private static string Quote(string value)
        {
            return "\"" + value.Replace("\"", "\\\"") + "\"";
        }

        private void SetBusy(bool busy, string message)
        {
            _busy = busy;
            btnInstall.IsEnabled = !busy;
            btnTest.IsEnabled = !busy;
            btnRevert.IsEnabled = !busy;
            btnBrowse.IsEnabled = !busy;
            if (btnIndicator != null) btnIndicator.IsEnabled = !busy;
            if (btnRefresh != null) btnRefresh.IsEnabled = !busy;
            if (btnHdrSettings != null) btnHdrSettings.IsEnabled = !busy;
            if (btnCopyLaunch != null) btnCopyLaunch.IsEnabled = !busy;
            lblBusy.Text = message ?? "";
            Cursor = busy ? Cursors.Wait : Cursors.Arrow;
        }

        private void RunScript(string scriptName, string extraArgs, Action<bool> done)
        {
            if (_busy) return;

            string appDir = AppDomain.CurrentDomain.BaseDirectory;
            string script = Path.Combine(appDir, @"tools\" + scriptName);
            if (!File.Exists(script))
            {
                Log(scriptName + " not found.");
                if (done != null) done(false);
                return;
            }

            var args = new StringBuilder();
            args.Append("-ExecutionPolicy Bypass -NoProfile -File ");
            args.Append(Quote(script));
            if (!string.IsNullOrEmpty(extraArgs))
            {
                args.Append(' ');
                args.Append(extraArgs);
            }

            SetBusy(true, "Working…");
            ThreadPool.QueueUserWorkItem(delegate
            {
                int exit = -1;
                try
                {
                    var psi = new ProcessStartInfo
                    {
                        FileName = "powershell.exe",
                        Arguments = args.ToString(),
                        UseShellExecute = false,
                        CreateNoWindow = true,
                        RedirectStandardOutput = true,
                        RedirectStandardError = true,
                        StandardOutputEncoding = Encoding.UTF8,
                        StandardErrorEncoding = Encoding.UTF8
                    };
                    using (var proc = new Process { StartInfo = psi })
                    {
                        proc.OutputDataReceived += delegate(object s, DataReceivedEventArgs e)
                        {
                            if (e.Data != null)
                            {
                                Dispatcher.BeginInvoke(new Action(delegate { Log(e.Data); }));
                            }
                        };
                        proc.ErrorDataReceived += delegate(object s, DataReceivedEventArgs e)
                        {
                            if (e.Data != null)
                            {
                                Dispatcher.BeginInvoke(new Action(delegate { Log(e.Data); }));
                            }
                        };
                        proc.Start();
                        proc.BeginOutputReadLine();
                        proc.BeginErrorReadLine();
                        proc.WaitForExit();
                        exit = proc.ExitCode;
                    }
                }
                catch (Exception ex)
                {
                    Dispatcher.BeginInvoke(new Action(delegate { Log("ERROR: " + ex.Message); }));
                    exit = -1;
                }

                Dispatcher.BeginInvoke(new Action(delegate
                {
                    SetBusy(false, "");
                    if (done != null) done(exit == 0);
                }));
            });
        }

        private void ApplyAndInstall()
        {
            string gameDir = txtGamePath.Text.Trim();
            if (string.IsNullOrEmpty(gameDir) || !File.Exists(Path.Combine(gameDir, "cof.exe")))
            {
                MessageBox.Show("Select a Cry of Fear folder that contains cof.exe.", "Invalid path", MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            int width, height;
            if (!TryGetResolution(out width, out height)) return;

            double fov = Math.Round(sliderFov.Value, 2);
            bool windowed = cmbDisplayMode.SelectedIndex == 1;

            var extra = new StringBuilder();
            extra.Append("-GamePath ").Append(Quote(gameDir));
            extra.Append(" -Fov ").Append(fov.ToString("F2", CultureInfo.InvariantCulture));
            extra.Append(" -Width ").Append(width);
            extra.Append(" -Height ").Append(height);
            extra.Append(" -RawMouse:").Append(chkRawMouse.IsChecked == true ? "1" : "0");
            extra.Append(" -LowLatencyVsync:").Append(chkLowLatencyVsync.IsChecked == true ? "1" : "0");
            extra.Append(" -EngineRates:").Append(chkEngineRates.IsChecked == true ? "1" : "0");
            if (windowed) extra.Append(" -Windowed");
            if (chkSoftenedShader.IsChecked == true) extra.Append(" -Shader");
            if (chkRtxHdr.IsChecked != true) extra.Append(" -SkipProfile");

            _steamStatus = null;
            _profileStatus = null;
            Log("Starting Install.ps1…");
            RunScript("Install.ps1", extra.ToString(), delegate(bool ok)
            {
                RefreshStatus();
                if (ok)
                {
                    string launch = txtLaunch.Text;
                    try { Clipboard.SetText(launch); }
                    catch { }
                    Log("Launch options copied: " + launch);
                    SaveSettings();
                    string steamLine;
                    if (_steamStatus == "written")
                    {
                        steamLine = "Steam launch options written.\nIf Steam is open, close it once so it reloads them.\n\n" + launch;
                    }
                    else
                    {
                        steamLine =
                            "Launch options (copied — Steam was not updated):\n" + launch +
                            "\n\nPaste into Steam → Cry of Fear → Properties → Launch Options.\nClose Steam and click Install again to write them automatically.";
                    }
                    string profileLine = "";
                    if (_profileStatus == "skipped")
                        profileLine = "\nNVIDIA driver profile skipped.";
                    else if (_profileStatus == "imported")
                        profileLine = "\nNVIDIA driver profile imported.";
                    checklistBody.Text =
                        chipHdrText.Text + "\n" +
                        chipAutoText.Text + "\n" +
                        profileLine + "\n\n" +
                        steamLine;
                    checklistCard.Visibility = Visibility.Visible;
                    Log("Install finished.");
                }
                else
                {
                    MessageBox.Show("Install finished with errors. See the log.", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
                }
            });
        }

        private void CopyLaunchOptions()
        {
            UpdateLaunchOptions();
            string args = txtLaunch.Text;
            if (string.IsNullOrWhiteSpace(args))
            {
                return;
            }
            try
            {
                Clipboard.SetText(args);
                Log("Copied: " + args);
            }
            catch (Exception ex)
            {
                Log("Could not copy to clipboard: " + ex.Message);
            }
        }

        private static void OpenHdrSettings()
        {
            try
            {
                Process.Start(new ProcessStartInfo
                {
                    FileName = "ms-settings:display",
                    UseShellExecute = true
                });
            }
            catch (Exception ex)
            {
                MessageBox.Show("Could not open Windows display settings: " + ex.Message, "HDR settings", MessageBoxButton.OK, MessageBoxImage.Warning);
            }
        }

        private void ImportHdrIndicator()
        {
            Log("Importing RTX HDR indicator profile (on-screen marker)…");
            RunScript("Install.ps1", "-ProfileOnly -Indicator", delegate(bool ok)
            {
                RefreshStatus();
                if (ok) Log("Indicator profile imported. Launch the game to confirm RTX HDR, then click Install to hide the marker.");
                else MessageBox.Show("Profile import failed. Accept the UAC prompt and try again.", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
            });
        }

        private void RunDiagnostics()
        {
            Log("Running diagnostics…");
            string extra = "";
            if (!string.IsNullOrWhiteSpace(txtGamePath.Text))
                extra = "-GamePath " + Quote(txtGamePath.Text.Trim());
            RunScript("Test.ps1", extra, delegate
            {
                RefreshStatus();
            });
        }

        private void RevertStock()
        {
            if (MessageBox.Show("Revert all mod files and the driver profile to stock?\nSaves will not be touched.", "Confirm revert", MessageBoxButton.YesNo, MessageBoxImage.Question) != MessageBoxResult.Yes)
                return;

            Log("Reverting…");
            string extra = "";
            if (!string.IsNullOrWhiteSpace(txtGamePath.Text))
                extra = "-GamePath " + Quote(txtGamePath.Text.Trim());
            RunScript("Uninstall.ps1", extra, delegate(bool ok)
            {
                RefreshStatus();
                checklistCard.Visibility = Visibility.Collapsed;
                if (ok) Log("Reverted. Saves were not changed.");
                else MessageBox.Show("Revert finished with errors. See the log.", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
            });
        }

        private static string SettingsPath()
        {
            return Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "CryOfFearHDRConfig.json");
        }

        private static string JsonEscape(string value)
        {
            if (value == null) value = "";
            return value.Replace("\\", "\\\\").Replace("\"", "\\\"");
        }

        private static string JsonString(string json, string key, string fallback)
        {
            Match m = Regex.Match(json, "\"" + Regex.Escape(key) + "\"\\s*:\\s*\"((?:\\\\.|[^\"\\\\])*)\"");
            if (!m.Success) return fallback;
            return m.Groups[1].Value.Replace("\\\"", "\"").Replace("\\\\", "\\");
        }

        private static bool JsonBool(string json, string key, bool fallback)
        {
            Match m = Regex.Match(json, "\"" + Regex.Escape(key) + "\"\\s*:\\s*(true|false)", RegexOptions.IgnoreCase);
            if (!m.Success) return fallback;
            return m.Groups[1].Value.Equals("true", StringComparison.OrdinalIgnoreCase);
        }

        private static double JsonDouble(string json, string key, double fallback)
        {
            Match m = Regex.Match(json, "\"" + Regex.Escape(key) + "\"\\s*:\\s*(-?[0-9.]+)");
            double v;
            if (!m.Success || !double.TryParse(m.Groups[1].Value, NumberStyles.Float, CultureInfo.InvariantCulture, out v))
                return fallback;
            return v;
        }

        private static int JsonInt(string json, string key, int fallback)
        {
            Match m = Regex.Match(json, "\"" + Regex.Escape(key) + "\"\\s*:\\s*(-?[0-9]+)");
            int v;
            if (!m.Success || !int.TryParse(m.Groups[1].Value, NumberStyles.Integer, CultureInfo.InvariantCulture, out v))
                return fallback;
            return v;
        }

        private void SaveSettings()
        {
            try
            {
                var choice = CurrentChoice();
                var sb = new StringBuilder();
                sb.Append("{\r\n");
                sb.Append("  \"GamePath\": \"").Append(JsonEscape(txtGamePath.Text.Trim())).Append("\",\r\n");
                sb.Append("  \"Width\": ").Append(txtWidth.Text.Trim()).Append(",\r\n");
                sb.Append("  \"Height\": ").Append(txtHeight.Text.Trim()).Append(",\r\n");
                sb.Append("  \"IsCustom\": ").Append(choice != null && choice.IsCustom ? "true" : "false").Append(",\r\n");
                sb.Append("  \"IsDesktop\": ").Append(choice != null && choice.IsDesktop ? "true" : "false").Append(",\r\n");
                sb.Append("  \"Windowed\": ").Append(cmbDisplayMode.SelectedIndex == 1 ? "true" : "false").Append(",\r\n");
                sb.Append("  \"Fov\": ").Append(Math.Round(sliderFov.Value, 2).ToString("F2", CultureInfo.InvariantCulture)).Append(",\r\n");
                sb.Append("  \"RawMouse\": ").Append(chkRawMouse.IsChecked == true ? "true" : "false").Append(",\r\n");
                sb.Append("  \"LowLatencyVsync\": ").Append(chkLowLatencyVsync.IsChecked == true ? "true" : "false").Append(",\r\n");
                sb.Append("  \"EngineRates\": ").Append(chkEngineRates.IsChecked == true ? "true" : "false").Append(",\r\n");
                sb.Append("  \"RtxHdr\": ").Append(chkRtxHdr.IsChecked == true ? "true" : "false").Append(",\r\n");
                sb.Append("  \"SoftenedShader\": ").Append(chkSoftenedShader.IsChecked == true ? "true" : "false").Append("\r\n");
                sb.Append("}\r\n");
                File.WriteAllText(SettingsPath(), sb.ToString());
            }
            catch (Exception ex)
            {
                Log("Could not save settings: " + ex.Message);
            }
        }

        private bool LoadSettings()
        {
            string path = SettingsPath();
            if (!File.Exists(path)) return false;
            string json;
            try { json = File.ReadAllText(path); }
            catch { return false; }

            string game = JsonString(json, "GamePath", "");
            if (!string.IsNullOrEmpty(game)) txtGamePath.Text = game;

            chkRawMouse.IsChecked = JsonBool(json, "RawMouse", true);
            chkLowLatencyVsync.IsChecked = JsonBool(json, "LowLatencyVsync", true);
            chkEngineRates.IsChecked = JsonBool(json, "EngineRates", true);
            chkRtxHdr.IsChecked = JsonBool(json, "RtxHdr", true);
            chkSoftenedShader.IsChecked = JsonBool(json, "SoftenedShader", false);
            cmbDisplayMode.SelectedIndex = JsonBool(json, "Windowed", false) ? 1 : 0;

            double fov = JsonDouble(json, "Fov", 1.15);
            if (fov < sliderFov.Minimum) fov = sliderFov.Minimum;
            if (fov > sliderFov.Maximum) fov = sliderFov.Maximum;
            sliderFov.Value = fov;

            bool isCustom = JsonBool(json, "IsCustom", false);
            bool isDesktop = JsonBool(json, "IsDesktop", true);
            int width = JsonInt(json, "Width", 0);
            int height = JsonInt(json, "Height", 0);

            if (isDesktop)
            {
                cmbResolution.SelectedIndex = 0;
            }
            else if (isCustom)
            {
                for (int i = 0; i < cmbResolution.Items.Count; i++)
                {
                    var c = cmbResolution.Items[i] as ResolutionChoice;
                    if (c != null && c.IsCustom)
                    {
                        cmbResolution.SelectedIndex = i;
                        break;
                    }
                }
                if (width >= 640) txtWidth.Text = width.ToString(CultureInfo.InvariantCulture);
                if (height >= 480) txtHeight.Text = height.ToString(CultureInfo.InvariantCulture);
            }
            else if (width >= 640 && height >= 480)
            {
                bool found = false;
                for (int i = 0; i < cmbResolution.Items.Count; i++)
                {
                    var c = cmbResolution.Items[i] as ResolutionChoice;
                    if (c != null && !c.IsCustom && c.Width == width && c.Height == height)
                    {
                        cmbResolution.SelectedIndex = i;
                        found = true;
                        break;
                    }
                }
                if (!found)
                {
                    txtWidth.Text = width.ToString(CultureInfo.InvariantCulture);
                    txtHeight.Text = height.ToString(CultureInfo.InvariantCulture);
                }
            }

            Log("Loaded previous settings.");
            return !string.IsNullOrEmpty(game);
        }

        [DllImport("user32.dll")]
        private static extern bool EnumDisplaySettings(string deviceName, int modeNum, ref DEVMODE devMode);

        [DllImport("user32.dll")]
        private static extern int GetSystemMetrics(int nIndex);

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Ansi)]
        private struct DEVMODE
        {
            private const int CCHDEVICENAME = 32;
            private const int CCHFORMNAME = 32;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = CCHDEVICENAME)]
            public string dmDeviceName;
            public short dmSpecVersion;
            public short dmDriverVersion;
            public short dmSize;
            public short dmDriverExtra;
            public int dmFields;
            public int dmPositionX;
            public int dmPositionY;
            public int dmDisplayOrientation;
            public int dmDisplayFixedOutput;
            public short dmColor;
            public short dmDuplex;
            public short dmYResolution;
            public short dmTTOption;
            public short dmCollate;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = CCHFORMNAME)]
            public string dmFormName;
            public short dmLogPixels;
            public int dmBitsPerPel;
            public int dmPelsWidth;
            public int dmPelsHeight;
            public int dmDisplayFlags;
            public int dmDisplayFrequency;
            public int dmICMMethod;
            public int dmICMIntent;
            public int dmMediaType;
            public int dmDitherType;
            public int dmReserved1;
            public int dmReserved2;
            public int dmPanningWidth;
            public int dmPanningHeight;
        }
    }

    internal static class HdrProbe
    {
        [StructLayout(LayoutKind.Sequential)]
        private struct LUID { public uint Low; public int High; }
        [StructLayout(LayoutKind.Sequential)]
        private struct SOURCE { public LUID adapterId; public uint id; public uint modeInfoIdx; public uint statusFlags; }
        [StructLayout(LayoutKind.Sequential)]
        private struct RATIONAL { public uint num; public uint den; }
        [StructLayout(LayoutKind.Sequential)]
        private struct TARGET
        {
            public LUID adapterId; public uint id; public uint modeInfoIdx;
            public uint outputTechnology; public uint rotation; public uint scaling;
            public RATIONAL refreshRate; public uint scanLineOrdering;
            public int targetAvailable; public uint statusFlags;
        }
        [StructLayout(LayoutKind.Sequential)]
        private struct PATH { public SOURCE sourceInfo; public TARGET targetInfo; public uint flags; }
        [StructLayout(LayoutKind.Sequential)]
        private struct MODE
        {
            public uint infoType; public uint id; public LUID adapterId;
            [MarshalAs(UnmanagedType.ByValArray, SizeConst = 48)]
            public byte[] blob;
        }
        [StructLayout(LayoutKind.Sequential)]
        private struct HEADER { public uint type; public uint size; public LUID adapterId; public uint id; }
        [StructLayout(LayoutKind.Sequential)]
        private struct GET_COLOR { public HEADER header; public uint value; public uint colorEncoding; public uint bitsPerColorChannel; }

        [DllImport("user32.dll")]
        private static extern int GetDisplayConfigBufferSizes(uint flags, out uint numPath, out uint numMode);
        [DllImport("user32.dll")]
        private static extern int QueryDisplayConfig(uint flags, ref uint numPath, [Out] PATH[] paths, ref uint numMode, [Out] MODE[] modes, IntPtr topo);
        [DllImport("user32.dll")]
        private static extern int DisplayConfigGetDeviceInfo(ref GET_COLOR info);

        public static void TryProbe(out bool queried, out bool anyOn)
        {
            queried = false;
            anyOn = false;
            try
            {
                uint np, nm;
                if (GetDisplayConfigBufferSizes(2, out np, out nm) != 0) return;
                PATH[] paths = new PATH[np];
                MODE[] modes = new MODE[nm];
                if (QueryDisplayConfig(2, ref np, paths, ref nm, modes, IntPtr.Zero) != 0) return;
                queried = true;
                for (int i = 0; i < np; i++)
                {
                    var t = paths[i].targetInfo;
                    GET_COLOR g = new GET_COLOR();
                    g.header.type = 9;
                    g.header.size = (uint)Marshal.SizeOf(typeof(GET_COLOR));
                    g.header.adapterId = t.adapterId;
                    g.header.id = t.id;
                    if (DisplayConfigGetDeviceInfo(ref g) != 0) continue;
                    if ((g.value & 2) != 0) anyOn = true;
                }
            }
            catch { }
        }
    }
}
