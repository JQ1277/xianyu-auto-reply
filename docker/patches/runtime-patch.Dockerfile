ARG BASE_IMAGE
FROM ${BASE_IMAGE}

# 仅覆盖本次修复涉及的公共代码，运行时依赖沿用已验证镜像，避免远程/本地重复拉取 Playwright 依赖。
COPY common/services/item_service.py /app/common/services/item_service.py
COPY common/utils/cookie_refresh.py /app/common/utils/cookie_refresh.py
