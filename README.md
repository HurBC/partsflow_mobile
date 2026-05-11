# PartsFlow Mobile

## Instalación del entorno Android en Arch Linux

### 1. Dependencias base

```bash
sudo pacman -S base-devel git curl unzip
```

### 2. Java (JDK 17)

```bash
sudo pacman -S jdk17-openjdk
sudo archlinux-java set java-17-openjdk
java -version   # verificar
```

### 3. Android Studio (vía AUR)

```bash
# Con yay:
yay -S android-studio

# Con paru:
paru -S android-studio
```

Abrí Android Studio una vez para que descargue el SDK base. El SDK se instala por defecto en `~/Android/Sdk`.

### 4. Variables de entorno

Agregá esto a `~/.zshrc` (o `~/.bashrc`):

```bash
export ANDROID_HOME=$HOME/Android/Sdk
export PATH=$PATH:$ANDROID_HOME/emulator
export PATH=$PATH:$ANDROID_HOME/platform-tools
export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin
```

Recargá el shell:

```bash
source ~/.zshrc
```

### 5. Aceptar licencias de Android

```bash
flutter doctor --android-licenses
# Escribí "y" a todo
```

### 6. Verificar estado

```bash
flutter doctor -v
```

Todos los checks de Android deberían estar en verde. Si falta algún SDK component, Android Studio → SDK Manager te lo muestra.

---

## Problemas frecuentes en Arch

| Problema | Solución |
|---|---|
| `kvm` no disponible para emulador | `sudo usermod -aG kvm $USER` + reiniciar sesión |
| `cmdline-tools` no encontrado | Instalarlo desde SDK Manager → SDK Tools → Android SDK Command-line Tools |
| Flutter no encuentra el SDK | Correr `flutter config --android-sdk $ANDROID_HOME` |
| Emulador lento | Asegurarse de tener `intel-ucode` o `amd-ucode` y KVM activo |

---

## Alternativa: SDK sin Android Studio

Si no querés instalar Android Studio, podés usar el paquete AUR `android-sdk` + `android-sdk-platform-tools` y manejar todo por CLI, pero es más tedioso. Para desarrollo Flutter, Android Studio es el camino más directo.
