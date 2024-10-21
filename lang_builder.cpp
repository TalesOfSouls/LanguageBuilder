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

#include "../GameEngine/localization/Language.h"
#include "../GameEngine/utils/StringUtils.h"

Language* languages;
int lang_index = 0;

#if _WIN32
void iter_directories_recursive(RingMemory* ring, const char *dir_path) {
    WIN32_FIND_DATAA findFileData;
    HANDLE hFind = INVALID_HANDLE_VALUE;
    char path[MAX_PATH];
    char searchPath[MAX_PATH];

    snprintf(searchPath, sizeof(searchPath), "%s\\*", dir_path);

    hFind = FindFirstFileA(searchPath, &findFileData);
    if (hFind == INVALID_HANDLE_VALUE) {
        fprintf(stderr, "FindFirstFile failed (%d)\n", GetLastError());
        return;
    }

    do {
        if (findFileData.cFileName[0] == '.') {
            continue;
        }

        snprintf(path, sizeof(path), "%s\\%s", dir_path, findFileData.cFileName);

        if (findFileData.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) {
            iter_directories_recursive(ring, path);
        } else if (findFileData.dwFileAttributes & FILE_ATTRIBUTE_ARCHIVE) {
            const char *ext = strrchr(findFileData.cFileName, '.');

            if (ext && strcmp(ext, ".langtxt") == 0) {
                char abs_path[MAX_PATH];
                if (GetFullPathNameA(path, sizeof(abs_path), abs_path, NULL)) {
                    printf("Found .langtxt file: %s\n", abs_path);

                    languages[lang_index].data = (byte *) calloc(32, MEGABYTE);
                    language_from_file_txt(ring, abs_path, languages + lang_index);

                    char new_path[MAX_PATH];
                    str_replace(abs_path, ".langtxt", ".langbin", new_path);
                    language_to_file(ring, new_path, languages + lang_index);

                    free(languages[lang_index].data);

                    ++lang_index;
                }
            }
        }
    } while (FindNextFileA(hFind, &findFileData) != 0);

    FindClose(hFind);
}
#else
void iter_directories_recursive(RingMemory* ring, const char *dir_path) {
    struct dirent *entry;
    DIR *dir = opendir(dir_path);

    if (!dir) {
        fprintf(stderr, "Could not open directory: %s\n", dir_path);
        return;
    }

    while ((entry = readdir(dir)) != NULL) {
        char path[PATH_MAX];
        struct stat statbuf;

        if (entry->d_name == '.') {
            continue;
        }

        snprintf(path, sizeof(path), "%s/%s", dir_path, entry->d_name);
        if (stat(path, &statbuf) != 0) {
            continue;
        }

        if (S_ISDIR(statbuf.st_mode)) {
            iter_directories_recursive(ring, path);
        } else if (S_ISREG(statbuf.st_mode)) {
            const char *ext = strrchr(entry->d_name, '.');
            if (ext && strcmp(ext, ".langtxt") == 0) {
                char abs_path[PATH_MAX];
                if (realpath(path, abs_path)) {
                    printf("Found .langtxt file: %s\n", abs_path);

                    languages[lang_index].data = (byte *) calloc(32, MEGABYTE);
                    language_from_file_txt(ring, abs_path, languages + lang_index);

                    char new_path[MAX_PATH];
                    str_replace(abs_path, ".langtxt", ".langbin", new_path);
                    language_to_file(ring, new_path, languages + lang_index);

                    free(languages[lang_index].data);

                    ++lang_index;
                }
            }
        }
    }

    closedir(dir);
}
#endif

int main(int argc, char *argv[])
{
    if (argc < 2) {
        fprintf(stderr, "Usage: %s <directory>\n", argv[0]);
        return EXIT_FAILURE;
    }

    RingMemory memory_volatile = {};
    memory_volatile.memory = (byte *) malloc(sizeof(byte) * GIGABYTE * 1);
    memory_volatile.size = sizeof(byte) * GIGABYTE * 1;

    int lang_count = 1000;
    languages = (Language *) malloc(sizeof(Language) * lang_count);

    iter_directories_recursive(&memory_volatile, argv[1]);

    printf("Language Files %d\n", lang_index);
}
