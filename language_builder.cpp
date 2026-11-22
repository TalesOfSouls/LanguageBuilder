/**
 * LanguageBuilder: converts every .langtxt file of a directory (recursive) into a .langbin file next to it
 *
 * Usage:
 *      language_builder <directory>
 *
 * The exit code is 1 if a file couldn't be converted (the other files are still converted)
 *
 * @copyright Jingga
 * @license   OMS License 2.0
 * @link      https://jingga.app
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#if _WIN32
    #include <windows.h>
#else
    #include <dirent.h>
    #include <sys/stat.h>
    #include <unistd.h>
    #include <limits.h>
#endif

#include "../cOMS/utils/StringUtils.h"
#include "../cOMS/system/FileUtils.cpp"
#include "../cOMS/memory/RingMemory.h"
#include "../cOMS/localization/Language.cpp"

static int32 _lang_count = 0;
static int32 _lang_errors = 0;

/**
 * Converts one .langtxt file into a .langbin file next to it
 *
 * @param const char* abs_path Absolute path of the .langtxt file
 *
 * @return bool false on error (error printed)
 */
static
bool build_language(const char* abs_path, RingMemory* const ring)
{
    printf("Found .langtxt file: %s\n", abs_path);

    FileBody input = {0};
    file_read(abs_path, &input, ring);
    if (!input.content) {
        fprintf(stderr, "\x1b[31mCouldn't read %s\x1b[0m\n", abs_path);

        return false;
    }

    // Exact upper bound of the memory -> language_from_txt can't run out of memory
    const int32 capacity = language_txt_memory_size((const char *) input.content, (int32) input.size);

    Language lang = {0};
    lang.data = memory_get(ring, capacity, sizeof(size_t));

    if (language_from_txt(&lang, (const char *) input.content, (int32) input.size, capacity) < 0) {
        fprintf(stderr, "\x1b[31mCouldn't parse %s\x1b[0m\n", abs_path);

        return false;
    }

    FileBody output = {0};
    output.content = memory_get(ring, lang.size, sizeof(size_t));
    output.size = language_to_data(&lang, output.content);

    char new_path[PATH_MAX_LENGTH];
    str_replace(abs_path, ".langtxt", ".langbin", new_path);
    file_write(new_path, &output);

    return true;
}

static
void build_file(const char* path, const char* file_name, RingMemory* const ring)
{
    const char* const ext = str_right(file_name, '.');
    if (!ext || str_compare(ext, ".langtxt") != 0) {
        return;
    }

    char abs_path[PATH_MAX_LENGTH];
#if _WIN32
    const bool resolved = GetFullPathNameA(path, sizeof(abs_path), abs_path, NULL) != 0;
#else
    const bool resolved = realpath(path, abs_path) != NULL;
#endif

    if (!resolved || !build_language(abs_path, ring)) {
        ++_lang_errors;

        return;
    }

    ++_lang_count;
}

#if _WIN32
static
bool iter_directories_recursive(RingMemory* const ring, const char* dir_path)
{
    WIN32_FIND_DATAA find_data;
    char path[PATH_MAX_LENGTH];
    char search_path[PATH_MAX_LENGTH];

    sprintf_fast(search_path, sizeof(search_path), "%s\\*", dir_path);

    HANDLE find = FindFirstFileA(search_path, &find_data);
    if (find == INVALID_HANDLE_VALUE) {
        fprintf(stderr, "Could not open directory: %s\n", dir_path);

        return false;
    }

    do {
        // ., .. + hidden files/directories
        if (find_data.cFileName[0] == '.') {
            continue;
        }

        sprintf_fast(path, sizeof(path), "%s%c%s", dir_path, '\\', find_data.cFileName);

        if (find_data.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) {
            iter_directories_recursive(ring, path);
        } else {
            build_file(path, find_data.cFileName, ring);
        }
    } while (FindNextFileA(find, &find_data) != 0);

    FindClose(find);

    return true;
}
#else
static
bool iter_directories_recursive(RingMemory* const ring, const char* dir_path)
{
    DIR* dir = opendir(dir_path);
    if (!dir) {
        fprintf(stderr, "Could not open directory: %s\n", dir_path);

        return false;
    }

    const struct dirent* entry;
    while ((entry = readdir(dir)) != NULL) {
        // ., .. + hidden files/directories
        if (entry->d_name[0] == '.') {
            continue;
        }

        char path[PATH_MAX_LENGTH];
        sprintf_fast(path, sizeof(path), "%s/%s", dir_path, entry->d_name);

        struct stat statbuf;
        if (stat(path, &statbuf) != 0) {
            continue;
        }

        if (S_ISDIR(statbuf.st_mode)) {
            iter_directories_recursive(ring, path);
        } else if (S_ISREG(statbuf.st_mode)) {
            build_file(path, entry->d_name, ring);
        }
    }

    closedir(dir);

    return true;
}
#endif

int main(int argc, char *argv[])
{
    if (argc < 2) {
        fprintf(stderr, "Usage: %s <directory>\n", argv[0]);
        return EXIT_FAILURE;
    }

    RingMemory memory_volatile = {0};
    ring_alloc(&memory_volatile, 256 * MEGABYTE, 256 * MEGABYTE);

    if (!iter_directories_recursive(&memory_volatile, argv[1])) {
        return EXIT_FAILURE;
    }

    printf("Language Files %d\n", _lang_count);

    return _lang_errors ? EXIT_FAILURE : EXIT_SUCCESS;
}
