# More Docs

This repository serves as the source of a [website](https://moredocs.github.io). It is a collaborative project for developers by developers to help each other by providing additional documentation on Apple platforms.

## Why?
The idea is that if you struggled making something work because the documentation was not that much helping and you had to look deep down in forums, mailing lists or whatever to achieve your goal, it is possible that someone else will struggle too.

## Contributing
So if you discovered a way to do something regarding programming on Apple platforms and you think it might benefit to other or just notice a mistake in a post, don't hesitate to [fork the project](https://github.com/MoreDocs/moredocs.github.io/fork) and open a pull request, or to send an email to more.doc.gith@gmail.com.

### Writing a post
Posts are written in Markdown using the [Chirpy](https://github.com/cotes2020/jekyll-theme-chirpy) theme for Jekyll. You can find specificities of this Markdown using the following links
- [Text and typography](https://chirpy.cotes.page/posts/text-and-typography/)
- [Writing a new Post](https://chirpy.cotes.page/posts/write-a-new-post/)

If you need any help writing a post, feel free to ask a question in the [forums](https://github.com/MoreDocs/moredocs.github.io/discussions/new?category=q-a).

#### Naming
New posts should be named following this format: `YYYY-MM-dd-title-of-the-post.markdown` in the *_posts*  folder.

#### Post resources
If you want to share code examples in files, you are encouraged to make a new directory in the *_posts_resources*  folder. The directory should be named after your post title without the markdown file extension so `YYYY-MM-dd-title-of-the-post`. Feel free to add any file you want in this folder and to reference them in your post.

#### Meta
Meta information is added to each post to make it easier to find.
Meta information that are required for a post are:
-  title
-  date
-  categories (main and sub)
-  tags (using when needed tags that already exist)
-  a short description of the post

The meta information are provided using the following format in the post header (just the top of the file).
```yaml
---
layout: post
title: Your awesome post title
date: YYYY-MM-dd HH:mm:00 +0200
categories: [First Category, Sub Category]
tags: [first tag, second tag, ... , nth tag]
author: <your author id in the authors.yaml file>
description: A short description of your post.
---
```

#### Authoring
If it's the first time you write a post, you can modify the [*authors.yaml* ](https://github.com/MoreDocs/moredocs.github.io/blob/main/_data/authors.yaml) file in your pull request to add your name and a URL to your GitHub, Twitter or even LinkedIn profile.

#### Local testing
If you wish to see what your post will look like, you can run the website locally. To so:
1. Clone this repository.
2. [Install Jekyll](https://jekyllrb.com/docs/installation/).
3. Once everything is installed go to the cloned repository and run `bundle exec jekyll serve`. The website should be live at `http://localhost:4000`.

You can find more informations in the GitHub [help](https://docs.github.com/en/pages/setting-up-a-github-pages-site-with-jekyll/testing-your-github-pages-site-locally-with-jekyll).