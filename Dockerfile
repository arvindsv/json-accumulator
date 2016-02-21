# Build using: docker build -t json-accumulator .
FROM ruby:2.2-onbuild

EXPOSE 4567

CMD ["./accumulator.rb"]
