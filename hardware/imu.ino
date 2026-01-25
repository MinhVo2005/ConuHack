#include <Wire.h>
#include <math.h>
#include <BleMouse.h>
#include <Arduino.h>

BleMouse beenleMouse("Glove-3D-Pro", "ESP32", 100);

#define MPU9250_ADDR 0x68
static float gyroOffsetX = 0, gyroOffsetY = 0, gyroOffsetZ = 0;
static float remX = 0, remY = 0;
static unsigned long lastUs = 0;

// ---------------- Tuning ----------------
static constexpr float SENS_MOVE   = 15.0f; 
static constexpr float SENS_GYRO   = 20.0f;
static constexpr float DEADZONE    = 2.3f;
static constexpr float BOOST       = 8.0f;

// Drift compensation
static constexpr float DRIFT_COMP_Y = 0.0f;  // Adjust if still drifting (try -0.5 to -2.0)

// ---------------- Noise Filtering ----------------
// Low-pass filter for accelerometer (removes high-frequency noise)
static constexpr float ACCEL_ALPHA = 0.1f;  // 0.0 = max filtering, 1.0 = no filtering
static float filtAccelX = 0, filtAccelY = 0, filtAccelZ = 0;

// Low-pass filter for gyroscope (removes high-frequency noise)
static constexpr float GYRO_ALPHA = 0.1f;   // 0.0 = max filtering, 1.0 = no filtering
static float filtGyroX = 0, filtGyroY = 0, filtGyroZ = 0;

// Complementary filter for orientation (fuses accel + gyro)
static constexpr float COMP_ALPHA = 0.98f;  // Trust gyro 98%, accel 2%
static float filtRoll = 0, filtPitch = 0;

// Moving average filter for final output (smooths cursor movement)
static constexpr int AVG_SAMPLES = 5;
static float avgBufferX[AVG_SAMPLES] = {0};
static float avgBufferY[AVG_SAMPLES] = {0};
static int avgIndex = 0;

// Touch sensor
const uint8_t TOUCH_PIN_1 = 6;

void writeReg(uint8_t reg, uint8_t val) {
    Wire.beginTransmission(MPU9250_ADDR);
    Wire.write(reg); Wire.write(val);
    Wire.endTransmission(true);
}

bool readRegs(uint8_t startReg, uint8_t *buf, uint8_t n) {
    Wire.beginTransmission(MPU9250_ADDR);
    Wire.write(startReg);
    if (Wire.endTransmission(false) != 0) return false;
    Wire.requestFrom((uint16_t)MPU9250_ADDR, (size_t)n);
    for (uint8_t i = 0; i < n; i++) buf[i] = Wire.read();
    return true;
}

void calibrate() {
    Serial.println("Calibrating... Keep the glove still!");
    long sx=0, sy=0, sz=0;
    for(int i=0; i<500; i++) {
        uint8_t b[6];
        if(readRegs(0x43, b, 6)) {
            sx += (int16_t)((b[0]<<8)|b[1]);
            sy += (int16_t)((b[2]<<8)|b[3]);
            sz += (int16_t)((b[4]<<8)|b[5]);
        }
        delay(2);
    }
    gyroOffsetX = (sx/500.0f)/131.0f;
    gyroOffsetY = (sy/500.0f)/131.0f;
    gyroOffsetZ = (sz/500.0f)/131.0f;
    Serial.println("Calibration complete!");
}

float lowPassFilter(float input, float prevOutput, float alpha) {
    return alpha * input + (1.0f - alpha) * prevOutput;
}

float movingAverage(float input, float* buffer, int size, int& index) {
    buffer[index] = input;
    index = (index + 1) % size;
    
    float sum = 0;
    for(int i = 0; i < size; i++) {
        sum += buffer[i];
    }
    return sum / size;
}

void setup() {
    Serial.begin(115200);
    Wire.begin(8, 9);
    beenleMouse.begin();
    
    // Configure MPU9250 with hardware filtering
    writeReg(0x6B, 0x00);  // Wake up
    writeReg(0x1A, 0x03);  // Set DLPF to ~44Hz (reduces noise at hardware level)
    writeReg(0x1B, 0x00);  // Gyro: ±250°/s (most sensitive, less noise)
    writeReg(0x1C, 0x00);  // Accel: ±2g (most sensitive, less noise)
    
    delay(100);
    calibrate();
    lastUs = micros();
}

void loop() {
    unsigned long nowUs = micros();
    float dt = (nowUs - lastUs) * 1e-6f;
    lastUs = nowUs;
    if (dt > 0.05f) dt = 0.01f;

    uint8_t buf[14];
    if (!readRegs(0x3B, buf, 14)) return;

    // 1. Raw Data
    float ax = (int16_t)((buf[0]<<8)|buf[1]) / 16384.0f;
    float ay = (int16_t)((buf[2]<<8)|buf[3]) / 16384.0f;
    float az = (int16_t)((buf[4]<<8)|buf[5]) / 16384.0f;
    float gx = ((int16_t)((buf[8]<<8)|buf[9]) / 131.0f) - gyroOffsetX;
    float gy = ((int16_t)((buf[10]<<8)|buf[11]) / 131.0f) - gyroOffsetY;
    float gz = ((int16_t)((buf[12]<<8)|buf[13]) / 131.0f) - gyroOffsetZ;

    // 2. Apply Low-Pass Filters to Raw Data
    filtAccelX = lowPassFilter(ax, filtAccelX, ACCEL_ALPHA);
    filtAccelY = lowPassFilter(ay, filtAccelY, ACCEL_ALPHA);
    filtAccelZ = lowPassFilter(az, filtAccelZ, ACCEL_ALPHA);
    
    filtGyroX = lowPassFilter(gx, filtGyroX, GYRO_ALPHA);
    filtGyroY = lowPassFilter(gy, filtGyroY, GYRO_ALPHA);
    filtGyroZ = lowPassFilter(gz, filtGyroZ, GYRO_ALPHA);

    // 3. Calculate Orientation from Accelerometer
    float accelRoll  = atan2(filtAccelY, filtAccelZ);
    float accelPitch = atan2(-filtAccelX, sqrt(filtAccelY*filtAccelY + filtAccelZ*filtAccelZ));

    // 4. Integrate Gyroscope for Orientation Change
    float gyroRoll  = filtRoll  + filtGyroX * dt;
    float gyroPitch = filtPitch + filtGyroY * dt;

    // 5. Complementary Filter (Fuse Accel + Gyro) - PREVENTS DRIFT
    filtRoll  = COMP_ALPHA * gyroRoll  + (1.0f - COMP_ALPHA) * accelRoll;
    filtPitch = COMP_ALPHA * gyroPitch + (1.0f - COMP_ALPHA) * accelPitch;

    // 6. Compute Rotation Matrix Elements
    float cosR = cos(filtRoll),  sinR = sin(filtRoll);
    float cosP = cos(filtPitch), sinP = sin(filtPitch);

    // 7. FIXED: Symmetric World-Space Transformation
    // Transform accelerometer from sensor frame to world frame
    // This removes gravity component and corrects for hand orientation
    float worldAccX = filtAccelX * cosP + filtAccelZ * sinP;
    float worldAccY = filtAccelY * cosR - filtAccelZ * sinR * cosP + filtAccelX * sinR * sinP;
    
    // Remove gravity vector (1g downward in world frame)
    // When hand is level, gravity pulls down on Z-axis
    // After rotation, we need to subtract the gravity component
    float gravityMagnitude = sqrt(filtAccelX*filtAccelX + filtAccelY*filtAccelY + filtAccelZ*filtAccelZ);
    if (gravityMagnitude > 0.8f && gravityMagnitude < 1.2f) {
        // Only remove gravity if we're close to 1g (not actually accelerating)
        worldAccY -= gravityMagnitude * sinP * cosR;
    }

    // 8. FIXED: Use Yaw Rate Directly (No Cross-Coupling)
    // Gyro Z directly represents yaw (left/right rotation)
    // Gyro X directly represents pitch rate (up/down when hand is level)
    float worldRotX = filtGyroZ;  // Yaw → Horizontal movement
    float worldRotY = filtGyroX;  // Pitch rate → Vertical movement

    // 9. Calculate Raw Potential Movement (with drift compensation)
    float rawX = -(worldRotX * SENS_GYRO) - (worldAccX * SENS_MOVE);
    float rawY = -(worldRotY * SENS_GYRO) - (worldAccY * SENS_MOVE) + DRIFT_COMP_Y;

    // 10. Apply Moving Average to Output
    float smoothX = movingAverage(rawX, avgBufferX, AVG_SAMPLES, avgIndex);
    float smoothY = movingAverage(rawY, avgBufferY, AVG_SAMPLES, avgIndex);

    // 11. Apply Deadzone with Magnitude Preservation
    float magnitude = sqrt(smoothX * smoothX + smoothY * smoothY);
    float finalX = 0, finalY = 0;

    if (magnitude > DEADZONE) {
        // Scale down by deadzone but preserve direction
        float scale = (magnitude - DEADZONE) / magnitude;
        finalX = smoothX * scale;
        finalY = smoothY * scale;
    }

    // 12. Debug Output
    if (magnitude > DEADZONE) {
        Serial.printf("MOVING -> X: %d | Y: %d (Mag: %.1f)\n", 
                      (int)finalX, (int)finalY, magnitude);
    }

    // 13. Mouse Execution
    if (beenleMouse.isConnected() && touchRead(TOUCH_PIN_1) > 30000) {
        float tx = (finalX * dt * BOOST) + remX;
        float ty = (finalY * dt * BOOST) + remY;
        
        int8_t mx = (int8_t)constrain(roundf(tx), -127, 127);
        int8_t my = (int8_t)constrain(roundf(ty), -127, 127);
        
        remX = tx - mx; 
        remY = ty - my;

        if (mx != 0 || my != 0) beenleMouse.move(mx, my, 0);
    }

    delay(4);
}