from sqlalchemy.orm import Session
from fastapi import HTTPException
from models.environment import Environment


class EnvironmentService:
    def __init__(self, db: Session):
        self.db = db

    def _coerce_int(self, value, field_name: str) -> int:
        if value is None:
            return None
        if isinstance(value, bool):
            raise HTTPException(
                status_code=400,
                detail=f"{field_name} must be an integer"
            )
        if isinstance(value, float):
            if not value.is_integer():
                raise HTTPException(
                    status_code=400,
                    detail=f"{field_name} must be an integer"
                )
            return int(value)
        try:
            return int(value)
        except (TypeError, ValueError):
            raise HTTPException(
                status_code=400,
                detail=f"{field_name} must be an integer"
            )

    def _normalize_int(self, value, default: int, min_value: int, max_value: int) -> int:
        if value is None:
            return default
        if isinstance(value, bool):
            return default
        try:
            if isinstance(value, float):
                value = int(round(value))
            else:
                value = int(value)
        except (TypeError, ValueError):
            return default
        if value < min_value:
            return min_value
        if value > max_value:
            return max_value
        return value

    def get_environment(self) -> Environment:
        """Get current environment state."""
        env = self.db.query(Environment).filter(Environment.id == 1).first()
        if not env:
            # Create default environment if not exists
            env = Environment(
                id=1,
                temperature=20,
                humidity=50,
                wind_speed=0,
                noise="quiet",
                brightness=5
            )
            self.db.add(env)
            self.db.commit()
            self.db.refresh(env)
        else:
            normalized_temperature = self._normalize_int(env.temperature, 20, -30, 50)
            normalized_humidity = self._normalize_int(env.humidity, 50, 0, 100)
            normalized_wind_speed = self._normalize_int(env.wind_speed, 0, 0, 60)
            normalized_brightness = self._normalize_int(env.brightness, 5, 1, 10)
            valid_noise = ["quiet", "low", "med", "high", "boomboom"]
            normalized_noise = env.noise if env.noise in valid_noise else "quiet"

            if (
                env.temperature != normalized_temperature
                or env.humidity != normalized_humidity
                or env.wind_speed != normalized_wind_speed
                or env.brightness != normalized_brightness
                or env.noise != normalized_noise
            ):
                env.temperature = normalized_temperature
                env.humidity = normalized_humidity
                env.wind_speed = normalized_wind_speed
                env.brightness = normalized_brightness
                env.noise = normalized_noise
                self.db.commit()
                self.db.refresh(env)
        return env

    def update_environment(
        self,
        temperature: int = None,
        humidity: int = None,
        wind_speed: int = None,
        noise: str = None,
        brightness: int = None
    ) -> Environment:
        """Update environment with validation."""
        env = self.get_environment()

        if temperature is not None:
            temperature = self._coerce_int(temperature, "Temperature")
            if temperature < -30 or temperature > 50:
                raise HTTPException(
                    status_code=400,
                    detail="Temperature must be between -30 and 50"
                )
            env.temperature = temperature

        if humidity is not None:
            humidity = self._coerce_int(humidity, "Humidity")
            if humidity < 0 or humidity > 100:
                raise HTTPException(
                    status_code=400,
                    detail="Humidity must be between 0 and 100"
                )
            env.humidity = humidity

        if wind_speed is not None:
            wind_speed = self._coerce_int(wind_speed, "Wind speed")
            if wind_speed < 0 or wind_speed > 60:
                raise HTTPException(
                    status_code=400,
                    detail="Wind speed must be between 0 and 60"
                )
            env.wind_speed = wind_speed

        if noise is not None:
            valid_noise = ["quiet", "low", "med", "high", "boomboom"]
            if noise not in valid_noise:
                raise HTTPException(
                    status_code=400,
                    detail=f"Noise must be one of: {', '.join(valid_noise)}"
                )
            env.noise = noise

        if brightness is not None:
            brightness = self._coerce_int(brightness, "Brightness")
            if brightness < 1 or brightness > 10:
                raise HTTPException(
                    status_code=400,
                    detail="Brightness must be between 1 and 10"
                )
            env.brightness = brightness

        self.db.commit()
        self.db.refresh(env)
        return env

    def reset_environment(self) -> Environment:
        """Reset environment to defaults."""
        env = self.get_environment()
        env.temperature = 20
        env.humidity = 50
        env.wind_speed = 0
        env.noise = "quiet"
        env.brightness = 5
        self.db.commit()
        self.db.refresh(env)
        return env

    def get_adaptation_hints(self) -> dict:
        """Get UI adaptation hints based on environment."""
        env = self.get_environment()
        hints = {
            "visual": [],
            "interaction": []
        }

        # Brightness adaptations
        if env.brightness <= 3:
            hints["visual"].append("high_contrast")
        if env.brightness >= 8:
            hints["visual"].append("reduce_brightness")

        # Noise adaptations
        if env.noise in ["high", "boomboom"]:
            hints["interaction"].append("enable_haptic")
            hints["interaction"].append("larger_buttons")
        if env.noise == "boomboom":
            hints["interaction"].append("gesture_mode")

        # Wind adaptations
        if env.wind_speed > 20:
            hints["interaction"].append("larger_touch_targets")

        return hints
