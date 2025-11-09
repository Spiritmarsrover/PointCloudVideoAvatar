# 🌀 PointCloudVideoAvatar

**PointCloudVideoAvatar** is a VRChat avatar setup for **recording and encoding 3D point clouds** into video files using ShaderMotion-style encoding.  
It’s designed for creating **point cloud video recordings**, not playback or decoding.  

---

## 🛠️ Prerequisites

- **Unity** 2022.3.22f  
- **VRChat Avatar SDK 3.0**

---

## ⚙️ Setup

1. Download the code from GitHub  
   → Click **Code → Download ZIP**  
2. Extract the ZIP and drag the **`PointCloudVideoAvatar`** folder into your Unity **Assets**  
3. In Unity, open the prefab inside `PointCloudVideoAvatar/Prefab`  
4. Drag and drop the **Avatar Prefab** into your scene  
5. **Detach the Blueprint ID**  
6. Open the **VRC Avatar SDK** panel  
7. Set your avatar’s **Name** and **Picture**  
8. Click **Upload Avatar to VRChat**

---

## 🧭 Usage

You can test or upload your own version.  
*(A sample avatar may be provided later.)*

1. Open the **Radial Menu** (hold down Menu button or press `R` on desktop)
2. Go to **Expressions**
3. You’ll see these options:
   - **Enable360Cam (HEAVY PERF)** – Turns on point cloud capture  
   - **World Drop** – Places the capture sphere in the world  
   - **ToggleMesh** – Hides or shows your avatar body  
   - **STICK/HEAD** – Switches camera between head or stick position
4. Start by clicking **Enable360Cam (HEAVY PERF)**  
5. You’ll see a **Capture Sphere** (bright, uncomfortable to look at) and a small **screen follower**
6. **ToggleMesh** to make your avatar invisible if desired  
7. Use **World Drop** to place the capture sphere somewhere stable  
8. **STICK/HEAD** to move the camera mount point
9. Open your VRChat **camera** and double-click the icon to view
10. In “Anchor,” select **World** so it stops following your player
11. Grab the camera lens and place it **inside the Capture Sphere**
12. In the right-side camera settings, set **Camera Resolution** to **8K**
13. Use the VRChat camera to **capture** your image or video  
    *(Later you can stretch the video to 2:1 equirectangular if needed.)*

---

## 🎥 How It Works

The avatar’s shader encodes scene information into a **video texture** using ShaderMotion’s data layout.  
- The **top half** of each frame stores **color**.  
- The **bottom half** stores **depth**, encoded in HSV (“chuting”).  
- Extra metadata is written to reserved “slots” in the video frame for camera and projection data.

---

## 🧩 Data Format

| Region | Description | Notes |
|--------|--------------|-------|
| **Top Half** | RGB color | Encoded in HSV “chuting” |
| **Bottom Half** | Depth map | Also encoded in HSV |
| **Encoding Precision** | 8-bit RGB | No alpha |
| **Recommended Video Bitrate** | 9000–12000 kbps | Higher bitrate = better depth precision |
| **Max Texture Resolution** | 1080p | Higher resolutions don’t increase point count |
| **File Formats** | MP4 / WebM | Works with ShaderMotion tools |

---

## 🧮 Camera Slot Layout

| Slot Range | Description |
|-------------|-------------|
| 0–2 | Position XYZ (high precision) |
| 3–5 | Position XYZ (low precision) |
| 6–9 | Quaternion XYZW |
| 10–11 | Field of View / Size |
| 12–13 | Near Plane |
| 14–15 | Far Plane |
| 16 | Projection Type (Orthographic / Perspective) |

---

## 🧠 Avatar Notes

- **Mesh Toggle** – Hides the avatar mesh (useful for invisible capture).  
- Reuses animation and expression controls from the **360Camera** avatar.  
- Designed purely for **recording and encoding** — no decoding or playback yet.  

---

## 🧪 Performance Tips

- **Lower your SteamVR resolution** to reduce GPU load.  
- **Higher frame rates** improve point cloud temporal precision.  
- **1080p is the recommended cap**; higher resolutions do not add more points.  
- You can record sequences or stream live data depending on your setup.

---

## 🚧 Known Limitations

- VRChat video textures are limited to **1080p** resolution.  
- No live decoding support (future project may handle this).  
- Frame rate and depth precision depend on your system’s performance.  

---

## 📚 Future Plans

- Avatar-side decoding & reconstruction.  
- Improved shader visualization.  
- Automatic equirectangular export format.

---

## 🧱 License

MIT License (or your preferred license here)

---

## 📸 Credits

- Original concept and shader work by **Spiritmarsrover**  
- Based on methods from **ShaderMotion** encoding system
