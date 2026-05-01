#include <QApplication>
#include <QMainWindow>
#include <QVBoxLayout>
#include <QHBoxLayout>
#include <QLabel>
#include <QPushButton>
#include <QSlider>
#include <QLineEdit>
#include <QTextEdit>
#include <QMediaPlayer>
#include <QFileDialog>
#include <QTimer>
#include <QBuffer>
#include <QDataStream>
#include <QFile>
#include <QMenuBar>
#include <QMessageBox>
#include <vector>
#include <algorithm>
#include <cmath>

// Struktur Data untuk Lirik
struct LyricEntry {
    double time;
    QString text;
};

class LyricMakerWindow : public QMainWindow {
private:
    QMediaPlayer* player;
    QByteArray audioData;
    QBuffer* audioBuffer;
    std::vector<LyricEntry> lyricData;
    QTimer* playbackTimer;

    // UI Elements
    QLabel* currentLyricDisplay;
    QLabel* timeLabel;
    QSlider* progressSlider;
    QPushButton* playPauseButton;
    QLineEdit* lyricInputField;
    QTextEdit* lyricLogView;

public:
    LyricMakerWindow() {
        setWindowTitle("LyricMaker");
        setMinimumSize(700, 500);

        player = new QMediaPlayer(this);
        audioBuffer = nullptr;

        // --- 1. SETUP MAIN LAYOUT ---
        QWidget* centralWidget = new QWidget(this);
        QVBoxLayout* mainLayout = new QVBoxLayout(centralWidget);
        mainLayout->setSpacing(20);
        mainLayout->setContentsMargins(20, 20, 20, 20);

        // --- 2. CURRENT LYRIC DISPLAY ---
        currentLyricDisplay = new QLabel("Load an MP3 or .lya file to begin.");
        QFont hugeFont = currentLyricDisplay->font();
        hugeFont.setPointSize(24);
        hugeFont.setBold(true);
        currentLyricDisplay->setFont(hugeFont);
        currentLyricDisplay->setAlignment(Qt::AlignCenter);
        currentLyricDisplay->setWordWrap(true);
        mainLayout->addWidget(currentLyricDisplay);

        // --- 3. AUDIO CONTROLS STACK ---
        QHBoxLayout* controlLayout = new QHBoxLayout();
        
        playPauseButton = new QPushButton("Play");
        timeLabel = new QLabel("00:00.0 / 00:00.0");
        QFont monoFont("Monospace");
        timeLabel->setFont(monoFont);
        
        progressSlider = new QSlider(Qt::Horizontal);
        
        controlLayout->addWidget(playPauseButton);
        controlLayout->addWidget(timeLabel);
        controlLayout->addWidget(progressSlider);
        mainLayout->addLayout(controlLayout);

        // --- 4. LYRIC INPUT STACK ---
        QHBoxLayout* inputLayout = new QHBoxLayout();
        lyricInputField = new QLineEdit();
        lyricInputField->setPlaceholderText("Type lyric here...");
        
        QPushButton* addLyricBtn = new QPushButton("Set at Current Time");
        
        inputLayout->addWidget(lyricInputField);
        inputLayout->addWidget(addLyricBtn);
        mainLayout->addLayout(inputLayout);

        // --- 5. LOG VIEW ---
        lyricLogView = new QTextEdit();
        lyricLogView->setReadOnly(true);
        mainLayout->addWidget(lyricLogView);

        setCentralWidget(centralWidget);

        // --- 6. SETUP MENU BAR ---
        QMenu* fileMenu = menuBar()->addMenu("File");
        
        QAction* openMp3Act = fileMenu->addAction("Open MP3...");
        openMp3Act->setShortcut(QKeySequence("Ctrl+O"));
        
        QAction* openLyaAct = fileMenu->addAction("Open .lya File...");
        openLyaAct->setShortcut(QKeySequence("Ctrl+Shift+O"));
        
        fileMenu->addSeparator();
        
        QAction* saveLyaAct = fileMenu->addAction("Save as .lya...");
        saveLyaAct->setShortcut(QKeySequence("Ctrl+S"));

        QMenu* lyricsMenu = menuBar()->addMenu("Lyrics");
        QAction* clearLyricsAct = lyricsMenu->addAction("Clear All Lyrics");
        clearLyricsAct->setShortcut(QKeySequence("Ctrl+K"));

        // --- 7. EVENT CONNECTIONS (C++11 Lambdas) ---
        connect(openMp3Act, &QAction::triggered, this, &LyricMakerWindow::openMP3);
        connect(openLyaAct, &QAction::triggered, this, &LyricMakerWindow::openLYA);
        connect(saveLyaAct, &QAction::triggered, this, &LyricMakerWindow::saveLYA);
        connect(clearLyricsAct, &QAction::triggered, this, &LyricMakerWindow::clearLyrics);
        
        connect(playPauseButton, &QPushButton::clicked, this, &LyricMakerWindow::togglePlayback);
        connect(addLyricBtn, &QPushButton::clicked, this, &LyricMakerWindow::addLyricAtCurrentTime);
        connect(lyricInputField, &QLineEdit::returnPressed, this, &LyricMakerWindow::addLyricAtCurrentTime);
        
        connect(progressSlider, &QSlider::sliderMoved, this, [=](int position) {
            if (player) player->setPosition(position);
        });

        // Timer untuk sinkronisasi UI (50ms)
        playbackTimer = new QTimer(this);
        connect(playbackTimer, &QTimer::timeout, this, &LyricMakerWindow::updateUI);
        playbackTimer->start(50);
    }

private:
    void openMP3() {
        QString fileName = QFileDialog::getOpenFileName(this, "Open MP3", "", "Audio Files (*.mp3)");
        if (!fileName.isEmpty()) {
            QFile file(fileName);
            if (file.open(QIODevice::ReadOnly)) {
                audioData = file.readAll();
                loadAudioFromData();
                clearLyrics();
            }
        }
    }

    void openLYA() {
        QString fileName = QFileDialog::getOpenFileName(this, "Open LYA", "", "Lyric Audio Files (*.lya)");
        if (!fileName.isEmpty()) {
            QFile file(fileName);
            if (file.open(QIODevice::ReadOnly)) {
                QDataStream in(&file);
                in.setVersion(QDataStream::Qt_5_15);
                
                quint32 lyricCount;
                in >> audioData >> lyricCount;
                
                lyricData.clear();
                for (quint32 i = 0; i < lyricCount; ++i) {
                    LyricEntry entry;
                    in >> entry.time >> entry.text;
                    lyricData.push_back(entry);
                }
                
                loadAudioFromData();
                refreshLyricLog();
            }
        }
    }

    void saveLYA() {
        if (audioData.isEmpty()) return;
        QString fileName = QFileDialog::getSaveFileName(this, "Save LYA", "MySong.lya", "Lyric Audio Files (*.lya)");
        if (!fileName.isEmpty()) {
            QFile file(fileName);
            if (file.open(QIODevice::WriteOnly)) {
                QDataStream out(&file);
                out.setVersion(QDataStream::Qt_5_15); // Format biner kompatibel Qt
                
                out << audioData;
                out << (quint32)lyricData.size();
                for (const auto& entry : lyricData) {
                    out << entry.time << entry.text;
                }
            }
        }
    }

    void loadAudioFromData() {
        if (audioBuffer) {
            audioBuffer->close();
            delete audioBuffer;
        }
        audioBuffer = new QBuffer(&audioData);
        audioBuffer->open(QIODevice::ReadOnly);
        
        player->setMedia(QMediaContent(), audioBuffer);
        playPauseButton->setText("Play");
        currentLyricDisplay->setText("Audio loaded. Ready to sync.");
    }

    void togglePlayback() {
        if (player->state() == QMediaPlayer::PlayingState) {
            player->pause();
            playPauseButton->setText("Play");
        } else {
            player->play();
            playPauseButton->setText("Pause");
        }
    }

    void addLyricAtCurrentTime() {
        QString text = lyricInputField->text();
        if (text.isEmpty() || audioData.isEmpty()) return;

        double currentTime = player->position() / 1000.0; // Konversi ms ke detik
        
        lyricData.push_back({currentTime, text});
        
        // Urutkan lirik berdasarkan waktu
        std::sort(lyricData.begin(), lyricData.end(), [](const LyricEntry& a, const LyricEntry& b) {
            return a.time < b.time;
        });

        lyricInputField->clear();
        refreshLyricLog();
    }

    void clearLyrics() {
        lyricData.clear();
        refreshLyricLog();
        currentLyricDisplay->setText("");
    }

    void refreshLyricLog() {
        QString log;
        for (const auto& entry : lyricData) {
            QString line;
            line.sprintf("[%02d:%04.1f] %s\n", 
                         (int)(entry.time / 60), 
                         std::fmod(entry.time, 60.0), 
                         entry.text.toUtf8().constData());
            log += line;
        }
        lyricLogView->setText(log);
    }

    void updateUI() {
        if (audioData.isEmpty()) return;

        qint64 currentMs = player->position();
        qint64 totalMs = player->duration();
        
        double currentSec = currentMs / 1000.0;
        double totalSec = totalMs / 1000.0;

        if (player->state() == QMediaPlayer::PlayingState && !progressSlider->isSliderDown()) {
            progressSlider->setMaximum(totalMs);
            progressSlider->setValue(currentMs);
        }

        QString timeStr;
        timeStr.sprintf("%02d:%04.1f / %02d:%04.1f", 
                        (int)(currentSec / 60), std::fmod(currentSec, 60.0),
                        (int)(totalSec / 60), std::fmod(totalSec, 60.0));
        timeLabel->setText(timeStr);

        // Cari lirik yang aktif
        QString displayText = "";
        for (const auto& entry : lyricData) {
            if (currentSec >= entry.time) {
                displayText = entry.text;
            } else {
                break;
            }
        }
        
        if (!displayText.isEmpty()) {
            currentLyricDisplay->setText(displayText);
        }
    }
};

int main(int argc, char *argv[]) {
    QApplication app(argc, argv);
    
    // Memaksa Qt menggunakan tema asli lingkungan Desktop KDE Plasma
    app.setAttribute(Qt::AA_UseHighDpiPixmaps);
    
    LyricMakerWindow window;
    window.show();
    
    return app.exec();
}