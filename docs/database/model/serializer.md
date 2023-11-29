# Serializer

Serializers are employed to transform the controller's response before sending it as an HTTP response.

## Create a serializer

```bash
dox create:serializer Blog
```

## Usage

=== "Serializer"

    ```dart
    class BlogSerializer extends Serializer<Blog> {
        BlogSerializer(super.data);

        @override
        Map<String, dynamic> convert(Blog m) {
            return {
                'uid': m.id,
                'title_en' : m.title,
            };
        }
    }
    ```

=== "Controller"

    ```dart
    class BlogController {
        getAllBlogs(DoxRequest req) async {
            List<Blog> blogs = await Blog().all();

            /// you can pass as list of data
            return BlogSerializer(blogs);
        }

        findBlog(DoxRequest req, id) async {
            Blog blog = await Blog().find(id);

            /// or you can also pass as single data
            return BlogSerializer(blog);
        }
    }
    ```

=== "Response"

    ```json
    {
        "uid" : "1",
        "title_en": "This is title"
    }
    ```

!!! info
    You can pass as **list of data** or **single data** into the serializer. Just make sure that you have injected your model type in serializer `Serializer<Blog>`.
