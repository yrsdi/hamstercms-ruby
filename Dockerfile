FROM docker.io/library/ruby:3.3.3

LABEL maintainer="Yadi Rosadi <yrsdi.id@gmail.com>"

RUN apt-get update -yqq && \
    apt-get install -yqq --no-install-recommends \
    build-essential \
    zip \
    vim \
    unzip \
    libpq-dev \
    libaio1 \
    libaio-dev \
    nodejs && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

ENV APP_HOME=/usr/src/app

COPY . $APP_HOME

RUN echo "gem: --no-rdoc --no-ri" >> ~/.gemrc

WORKDIR $APP_HOME

# Update Bundler
RUN gem install bundler

RUN bundle install

# Copy the application code into the container
COPY . .

# Expose the port that Sinatra will run on
EXPOSE 4567

# Set the default command to run your Sinatra app
CMD ["bundle", "exec", "ruby", "index.rb", "-o", "0.0.0.0", "-p", "4567", "-e", "production"]