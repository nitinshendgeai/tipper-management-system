"""
Tenant-aware query helpers.

Usage:
    vehicles = filter_by_company(db.query(Vehicle), Vehicle).all()

All queries on tenant-scoped models MUST go through filter_by_company to
guarantee complete data isolation between companies.
"""

from uuid import UUID
from sqlalchemy.orm import Query

from app.core.tenant import TenantContext


def filter_by_company(query: Query, model) -> Query:
    """
    Append a company_id WHERE clause to any SQLAlchemy query.

    The company_id is read from the current request's TenantContext,
    which is populated by the get_current_tenant_user dependency.
    """
    company_id: UUID = TenantContext.get_company_id()
    return query.filter(model.company_id == company_id)
