import pytest
from fastapi import HTTPException
from services.environment_service import EnvironmentService


class TestEnvironmentService:
    """Tests for EnvironmentService."""

    def test_get_environment_creates_default(self, db_session):
        """Test getting environment creates default if not exists."""
        service = EnvironmentService(db_session)
        env = service.get_environment()

        assert env.id == 1
        assert env.temperature == 20
        assert env.humidity == 50
        assert env.wind_speed == 0
        assert env.noise == "quiet"
        assert env.brightness == 5

    def test_update_temperature(self, db_session):
        """Test updating temperature."""
        service = EnvironmentService(db_session)
        env = service.update_environment(temperature=25)

        assert env.temperature == 25

    def test_update_temperature_out_of_range(self, db_session):
        """Test temperature validation."""
        service = EnvironmentService(db_session)

        with pytest.raises(HTTPException) as exc_info:
            service.update_environment(temperature=-50)

        assert exc_info.value.status_code == 400

        with pytest.raises(HTTPException) as exc_info:
            service.update_environment(temperature=60)

        assert exc_info.value.status_code == 400

    def test_update_humidity(self, db_session):
        """Test updating humidity."""
        service = EnvironmentService(db_session)
        env = service.update_environment(humidity=75)

        assert env.humidity == 75

    def test_update_humidity_out_of_range(self, db_session):
        """Test humidity validation."""
        service = EnvironmentService(db_session)

        with pytest.raises(HTTPException) as exc_info:
            service.update_environment(humidity=-10)

        assert exc_info.value.status_code == 400

        with pytest.raises(HTTPException) as exc_info:
            service.update_environment(humidity=110)

        assert exc_info.value.status_code == 400

    def test_update_wind_speed(self, db_session):
        """Test updating wind speed."""
        service = EnvironmentService(db_session)
        env = service.update_environment(wind_speed=30)

        assert env.wind_speed == 30

    def test_update_wind_speed_out_of_range(self, db_session):
        """Test wind speed validation."""
        service = EnvironmentService(db_session)

        with pytest.raises(HTTPException) as exc_info:
            service.update_environment(wind_speed=-5)

        assert exc_info.value.status_code == 400

        with pytest.raises(HTTPException) as exc_info:
            service.update_environment(wind_speed=100)

        assert exc_info.value.status_code == 400

    def test_update_noise(self, db_session):
        """Test updating noise level."""
        service = EnvironmentService(db_session)

        for noise in ["quiet", "low", "med", "high", "boomboom"]:
            env = service.update_environment(noise=noise)
            assert env.noise == noise

    def test_update_noise_invalid(self, db_session):
        """Test invalid noise level."""
        service = EnvironmentService(db_session)

        with pytest.raises(HTTPException) as exc_info:
            service.update_environment(noise="invalid")

        assert exc_info.value.status_code == 400

    def test_update_brightness(self, db_session):
        """Test updating brightness."""
        service = EnvironmentService(db_session)
        env = service.update_environment(brightness=8)

        assert env.brightness == 8

    def test_update_brightness_out_of_range(self, db_session):
        """Test brightness validation."""
        service = EnvironmentService(db_session)

        with pytest.raises(HTTPException) as exc_info:
            service.update_environment(brightness=0)

        assert exc_info.value.status_code == 400

        with pytest.raises(HTTPException) as exc_info:
            service.update_environment(brightness=11)

        assert exc_info.value.status_code == 400

    def test_update_multiple_properties(self, db_session):
        """Test updating multiple properties at once."""
        service = EnvironmentService(db_session)
        env = service.update_environment(
            temperature=30,
            humidity=80,
            wind_speed=25,
            noise="high",
            brightness=3
        )

        assert env.temperature == 30
        assert env.humidity == 80
        assert env.wind_speed == 25
        assert env.noise == "high"
        assert env.brightness == 3

    def test_reset_environment(self, db_session):
        """Test resetting environment to defaults."""
        service = EnvironmentService(db_session)

        # Change some values
        service.update_environment(
            temperature=40,
            humidity=90,
            noise="boomboom"
        )

        # Reset
        env = service.reset_environment()

        assert env.temperature == 20
        assert env.humidity == 50
        assert env.wind_speed == 0
        assert env.noise == "quiet"
        assert env.brightness == 5

    def test_get_adaptation_hints_low_brightness(self, db_session):
        """Test adaptation hints for low brightness."""
        service = EnvironmentService(db_session)
        service.update_environment(brightness=2)

        hints = service.get_adaptation_hints()

        assert "high_contrast" in hints["visual"]

    def test_get_adaptation_hints_high_brightness(self, db_session):
        """Test adaptation hints for high brightness."""
        service = EnvironmentService(db_session)
        service.update_environment(brightness=9)

        hints = service.get_adaptation_hints()

        assert "reduce_brightness" in hints["visual"]

    def test_get_adaptation_hints_high_noise(self, db_session):
        """Test adaptation hints for high noise."""
        service = EnvironmentService(db_session)
        service.update_environment(noise="high")

        hints = service.get_adaptation_hints()

        assert "enable_haptic" in hints["interaction"]
        assert "larger_buttons" in hints["interaction"]

    def test_get_adaptation_hints_extreme_noise(self, db_session):
        """Test adaptation hints for extreme noise."""
        service = EnvironmentService(db_session)
        service.update_environment(noise="boomboom")

        hints = service.get_adaptation_hints()

        assert "enable_haptic" in hints["interaction"]
        assert "larger_buttons" in hints["interaction"]
        assert "gesture_mode" in hints["interaction"]

    def test_get_adaptation_hints_high_wind(self, db_session):
        """Test adaptation hints for high wind."""
        service = EnvironmentService(db_session)
        service.update_environment(wind_speed=30)

        hints = service.get_adaptation_hints()

        assert "larger_touch_targets" in hints["interaction"]

    def test_get_adaptation_hints_default(self, db_session):
        """Test adaptation hints for default environment."""
        service = EnvironmentService(db_session)
        service.reset_environment()

        hints = service.get_adaptation_hints()

        assert hints["visual"] == []
        assert hints["interaction"] == []
