from sqlalchemy import (
    Column,
    Integer,
    String,
    Boolean,
    DateTime,
    Float
)

from datetime import datetime

from app.db.session import Base


class Route(Base):

    __tablename__ = "routes"
    __table_args__ = {"schema": "master"}

    id = Column(Integer, primary_key=True, index=True)

    source_location = Column(
        String(150),
        nullable=False
    )

    destination_location = Column(
        String(150),
        nullable=False
    )

    distance_km = Column(Float, nullable=True)

    # Operational planning fields — optional, used by trip module
    trip_rate = Column(Float, nullable=True)

    diesel_limit = Column(Float, nullable=True)

    estimated_hours = Column(Float, nullable=True)

    # Free-text notes for the route (nullable — run Alembic migration if adding
    # to an existing DB: alembic revision --autogenerate -m "add_remarks_to_routes"
    # then: alembic upgrade head)
    remarks = Column(String(255), nullable=True)

    is_active = Column(Boolean, default=True)

    created_at = Column(DateTime, default=datetime.utcnow)
