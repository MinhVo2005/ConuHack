from sqlalchemy import Column, Integer, String, DateTime, CheckConstraint
from datetime import datetime
from database import Base


class Environment(Base):
    __tablename__ = "environment"

    id = Column(Integer, primary_key=True)
    temperature = Column(Integer, default=20)
    humidity = Column(Integer, default=50)
    wind_speed = Column(Integer, default=0)
    noise = Column(String, default="quiet")
    brightness = Column(Integer, default=5)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    __table_args__ = (
        CheckConstraint("id = 1", name="single_row"),
        CheckConstraint("noise IN ('quiet', 'low', 'med', 'high', 'boomboom')", name="valid_noise"),
        CheckConstraint("brightness >= 1 AND brightness <= 10", name="valid_brightness"),
    )

    def to_dict(self):
        return {
            "id": self.id,
            "temperature": self.temperature,
            "humidity": self.humidity,
            "wind_speed": self.wind_speed,
            "noise": self.noise,
            "brightness": self.brightness,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None
        }
