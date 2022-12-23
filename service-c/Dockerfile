FROM public.ecr.aws/lambda/python:3.8 AS builder
WORKDIR ${LAMBDA_TASK_ROOT}
# all the packages of the monorepo we could depend on:
COPY dist/*.whl /tmp/
# the specific versions service-a depends on, based on the lockfile:
COPY info/requirements.txt /tmp/
# we append ourselves to the requirements.txt, to also install service-a
# hadolint ignore=SC2086
RUN echo "service-c" >> /tmp/requirements.txt && \
    python3 -m pip install --pre --no-cache-dir --find-links=/tmp/ -r /tmp/requirements.txt -t "${LAMBDA_TASK_ROOT}"

# A new docker layer to not have to include all build-tools/wheels
FROM public.ecr.aws/lambda/python:3.8
WORKDIR ${LAMBDA_TASK_ROOT}
COPY info/VERSION .
COPY --from=builder ${LAMBDA_TASK_ROOT} .
# Copy files that aren't part of the package
COPY ./app.py .

CMD ["app.handler"]