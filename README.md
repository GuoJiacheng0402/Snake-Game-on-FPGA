# Snake-Game-on-FPGA
# 🐍 Snake-Game-on-FPGA

Minimal Verilog HDL implementation of the Snake game with real-time HDMI output (1280×720@60Hz), designed for FPGA platforms.  
All game logic and pixel generation are included in the top-level module.

---

## 📚 Project Background

This project was originally developed as a course assignment for  
**"Chip & System II: Verilog and FPGA Design"** at SCUT.  
It is intended solely for educational and learning purposes.

---

## ✨ Features

- Real HDMI video output (1280×720 @ 60Hz)
- All game logic written in a single top-level Verilog file
- 4-way key control, random food, auto-growing snake, edge wrapping
- Clear, open-source code structure for learning and further development

---

## 📂 Project Structure


<pre>
snake-game-on-fpga/
├── top.v                  # Main Verilog module (snake logic + video)
├── stub/
│   ├── dvi_encoder_stub.v     # TMDS encoder stub (HDMI)
│   ├── video_pll_stub.v       # PLL stub
│   └── GTP_CLKBUFG_stub.v     # Clock buffer stub
├── LICENSE                    # MIT License
└── README.md
</pre>

---

## ⚠️ Notice: External Modules Not Included

The following modules are **referenced but NOT included** due to copyright:
- `dvi_encoder`: HDMI TMDS encoder (please provide your own)
- `video_pll`: Vendor PLL IP (regenerate as needed)
- `GTP_CLKBUFG`: Platform clock buffer primitive


---

## 🧑‍💻 Author

Jiacheng Guo  
2025-06-05

---

## 📖 License

This project is licensed under the MIT License. See [LICENSE](./LICENSE) for details.
