# Reproduction Script Guide

Having a reproduction script of an issue helps us a lot with processing it faster. We know some of our contributors
could not be familiarized with building reproduction scripts, so in this guide, we'll help you understand what is a 
reproduction script and provide a template and a couple of examples of some reproduction scripts.

## What is a reproduction script?

A reproduction script is basically a script that reproduces an event. Usually, they are used to reproduce issues, bugs, 
errors and/or warnings.

The core idea behind creating a reproduction script is to configure the different environment variables to be as similar as
possible with the environment trying to be reproduced.

After the environment has been configured properly the idea is to reproduce a series of events until reaching a specific 
point, which as mentioned before could be a bug, error, warning, or any other event, by using a series of commands.

## A template for reproduction scripts

Below you can find a template that may be used in order to create reproduction scripts related to bundle issues:

```sh
# Add here the code that could be used as a template for reproduction scripts.

# Be sure to include rich helpful comments which could help the readers understand the logic 
# behind the process.
```

## Reproduction scripts examples

Below you can find a couple of examples of reproduction scripts:

- [Git environment variables causing install to fail](https://gist.github.com/xaviershay/6207550)
- [Multiple gems in a repository cannot be updated independently](https://gist.github.com/xaviershay/6295889)
